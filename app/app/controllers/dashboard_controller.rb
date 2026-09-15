class DashboardController < ApplicationController
  before_action :require_auth

  def index
    attempts = current_user.test_attempts
                           .where.not(completed_at: nil)
                           .order(completed_at: :desc)

    slugs    = attempts.pluck(:test_slug).uniq
    meta_map = TestMetadatum.where(slug: slugs).index_by(&:slug)

    bookmarks = current_user.bookmarks.includes(:question).order(created_at: :desc)
    meta_slugs = bookmarks.map { |b| b.question.test_slug }.uniq
    bm_meta_map = TestMetadatum.where(slug: meta_slugs).index_by(&:slug)

    render inertia: "Dashboard", props: {
      attempts: attempts.map { |a|
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
      },
      stats: {
        total_attempts:  attempts.count,
        avg_score:       attempts.average(:score).to_f.round(1),
        best_score:      attempts.maximum(:score).to_f,
        tests_completed: slugs.count
      },
      weak_topics:       weak_topics.entries.map(&:to_h),
      recommended_tests: recommended_tests(slugs),
      bookmarks: bookmarks.map { |b|
        q = b.question
        {
          id:          b.id,
          question_id: q.id,
          question_text: q.text,
          test_slug:   q.test_slug,
          test_title:  bm_meta_map[q.test_slug]&.title || q.test_slug,
          options:     q.options,
          correct_ids: q.correct_ids,
          explanation: q.explanation
        }
      }
    }
  end

  private

  RECOMMENDED_TESTS_LIMIT = 4

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
