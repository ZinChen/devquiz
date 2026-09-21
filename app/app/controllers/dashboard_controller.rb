class DashboardController < ApplicationController
  before_action :require_auth

  PAGE_SIZE = 5

  def index
    attempts = completed_attempts
    slugs    = attempts.pluck(:test_slug).uniq

    render inertia: "Dashboard", props: {
      # Списки отдаются страницами: у активного пользователя их сотни, и
      # тянуть всё в каждый ответ незачем. Догружает #attempts / #bookmarks.
      attempts:      attempt_props(attempts.limit(PAGE_SIZE)),
      has_more_attempts: attempts.count > PAGE_SIZE,
      bookmarks:     bookmark_props(user_bookmarks.limit(PAGE_SIZE)),
      has_more_bookmarks: user_bookmarks.count > PAGE_SIZE,
      page_size:     PAGE_SIZE,
      # Сводка считается по всей истории, а не по показанной странице.
      stats: {
        total_attempts:  attempts.count,
        avg_score:       attempts.average(:score).to_f.round(1),
        tests_completed: slugs.count
      },
      weak_topics:       weak_topics.entries.map(&:to_h),
      strong_topics:     strong_topics.entries.map(&:to_h),
      recommended_tests: recommended_tests(slugs)
    }
  end

  # Следующая страница истории.
  def attempts
    scope = completed_attempts
    render json: {
      attempts: attempt_props(scope.offset(page_offset).limit(PAGE_SIZE)),
      has_more: scope.count > page_offset + PAGE_SIZE
    }
  end

  # Следующая страница избранных вопросов.
  def bookmarks
    scope = user_bookmarks
    render json: {
      bookmarks: bookmark_props(scope.offset(page_offset).limit(PAGE_SIZE)),
      has_more:  scope.count > page_offset + PAGE_SIZE
    }
  end

  private

  RECOMMENDED_TESTS_LIMIT = 4

  def page_offset
    params[:offset].to_i.clamp(0, 100_000)
  end

  def completed_attempts
    current_user.test_attempts.where.not(completed_at: nil).order(completed_at: :desc)
  end

  def user_bookmarks
    current_user.bookmarks.includes(:question).order(created_at: :desc)
  end

  def attempt_props(scope)
    records  = scope.to_a
    meta_map = TestMetadatum.where(slug: records.map(&:test_slug).uniq).index_by(&:slug)

    records.map do |a|
      {
        id:              a.id,
        test_slug:       a.test_slug,
        test_title:      meta_map[a.test_slug]&.title || a.test_slug,
        score:           a.score.to_f,
        correct_count:   a.correct_count,
        total_questions: a.total_questions,
        time_spent:      a.time_spent,
        completed_at:    a.completed_at,
        weak_only:       a.weak_only
      }
    end
  end

  def bookmark_props(scope)
    records  = scope.to_a
    meta_map = TestMetadatum.where(slug: records.map { |b| b.question.test_slug }.uniq).index_by(&:slug)

    records.map do |b|
      q = b.question
      {
        id:            b.id,
        question_id:   q.id,
        question_text: q.text,
        test_slug:     q.test_slug,
        test_title:    meta_map[q.test_slug]&.title || q.test_slug,
        options:       q.options,
        correct_ids:   q.correct_ids,
        explanation:   q.explanation
      }
    end
  end

  def weak_topics
    @weak_topics ||= WeakTopicsSummary.for(user: current_user)
  end

  def strong_topics
    @strong_topics ||= StrongTopicsSummary.for(user: current_user, exclude_slugs: weak_topics.slugs)
  end

  # Тесты, где реально есть вопросы по слабым темам. Ищем через TopicIndex, а
  # не по tags теста: темы вопроса (mvc, queries, indexes) в тегах тестов по
  # большей части не встречаются, и поиск по ним ничего бы не находил.
  #
  # Тест ранжируется по тому, НАСКОЛЬКО ПРОБЛЕМНУЮ тему он закрывает и
  # НАСКОЛЬКО ПЛОТНО — а не по числу разных тем: иначе широкий «сборный»
  # тест, задевающий десяток тем по одному вопросу, обходил бы узкий тест,
  # состоящий по большей части из вопросов по самой слабой теме пользователя —
  # тот полезнее, даже если тем в нём меньше. Непройденные идут первыми —
  # там пользы больше, чем в повторе уже знакомого.
  def recommended_tests(completed_slugs)
    return [] if weak_topics.slugs.empty?

    # Место темы в списке слабых (0 — самая проблемная) — по нему и ранжируем тесты.
    rank_of = weak_topics.entries.each_with_index.to_h { |topic, i| [ topic.slug, i ] }

    # Для каждого теста: подписи тем на карточку, лучший (наименьший) ранг
    # среди них и число вопросов именно по этой лучшей теме — плотность.
    labels_by_slug        = Hash.new { |h, k| h[k] = [] }
    rank_by_slug          = Hash.new(Float::INFINITY)
    best_topic_count_by_slug = Hash.new(0)

    weak_topics.entries.each do |topic|
      TopicIndex.question_ids_for(topic.slug).each do |slug, question_ids|
        labels_by_slug[slug] << topic.label

        rank = rank_of[topic.slug]
        next if rank > rank_by_slug[slug]

        # Более проблемная тема — переопределяем; при том же ранге не бывает
        # (у каждой темы свой уникальный ранг), так что достаточно "<".
        if rank < rank_by_slug[slug]
          rank_by_slug[slug] = rank
          best_topic_count_by_slug[slug] = question_ids.size
        end
      end
    end
    return [] if labels_by_slug.empty?

    meta_map = TestMetadatum.active.where(slug: labels_by_slug.keys).index_by(&:slug)

    labels_by_slug.filter_map { |slug, labels|
      meta = meta_map[slug]
      next unless meta

      { slug: slug, title: meta.title, topics: labels.uniq, completed: completed_slugs.include?(slug),
        best_rank: rank_by_slug[slug], best_topic_count: best_topic_count_by_slug[slug] }
    }.sort_by { |t| [ t[:completed] ? 1 : 0, t[:best_rank], -t[:best_topic_count] ] }
     .first(RECOMMENDED_TESTS_LIMIT)
     .map { |t| t.except(:best_rank, :best_topic_count) }
  end
end
