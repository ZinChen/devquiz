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
        completed_at:    a.completed_at
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

  # Тесты, где реально есть вопросы по слабым темам. Ищем через TopicIndex, а
  # не по tags теста: темы вопроса (mvc, queries, indexes) в тегах тестов по
  # большей части не встречаются, и поиск по ним ничего бы не находил.
  #
  # Тест тем ценнее, чем больше слабых тем он закрывает; непройденные идут
  # первыми — там пользы больше, чем в повторе уже знакомого.
  def recommended_tests(completed_slugs)
    return [] if weak_topics.slugs.empty?

    scored = Hash.new { |h, k| h[k] = [] }
    weak_topics.entries.each do |topic|
      TopicIndex.tests_for(topic.slug).each { |slug| scored[slug] << topic.label }
    end
    return [] if scored.empty?

    meta_map = TestMetadatum.active.where(slug: scored.keys).index_by(&:slug)

    scored.filter_map { |slug, labels|
      meta = meta_map[slug]
      next unless meta

      { slug: slug, title: meta.title, topics: labels.uniq, completed: completed_slugs.include?(slug) }
    }.sort_by { |t| [ t[:completed] ? 1 : 0, -t[:topics].size ] }
     .first(RECOMMENDED_TESTS_LIMIT)
  end
end
