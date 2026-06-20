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
end
