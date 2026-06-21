class TestAttemptsController < ApplicationController
  def index
    meta = TestMetadatum.find_by!(slug: params[:test_slug])
    attempts = TestAttempt.where(test_slug: params[:test_slug])
                          .where.not(completed_at: nil)
                          .order(completed_at: :desc)

    render inertia: "Tests/Attempts", props: {
      test: {
        slug:  meta.slug,
        title: meta.title,
      },
      attempts: attempts.map { |a|
        {
          id:              a.id,
          score:           a.score.to_f,
          correct_count:   a.correct_count,
          total_questions: a.total_questions,
          time_spent:      a.time_spent,
          completed_at:    a.completed_at
        }
      }
    }
  end
end
