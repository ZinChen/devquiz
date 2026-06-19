class DashboardController < ApplicationController
  before_action :require_auth

  def index
    attempts = current_user.test_attempts
                           .where.not(completed_at: nil)
                           .order(completed_at: :desc)

    slugs    = attempts.pluck(:test_slug).uniq
    meta_map = TestMetadatum.where(slug: slugs).index_by(&:slug)

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
      }
    }
  end
end
