class StatsController < ApplicationController
  def index
    top_tests = TestMetadatum.active.order(attempts_count: :desc).limit(10)
    recent    = TestAttempt.where.not(completed_at: nil)
                           .order(completed_at: :desc).limit(20)

    render inertia: "Stats", props: {
      global: {
        total_attempts: TestAttempt.where.not(completed_at: nil).count,
        total_users:    User.count,
        total_tests:    TestMetadatum.active.count,
        avg_score:      TestAttempt.where.not(completed_at: nil).average(:score).to_f.round(1)
      },
      top_tests: top_tests.map { |t|
        {
          slug:           t.slug,
          title:          t.title,
          attempts_count: t.attempts_count,
          avg_score:      t.avg_score.to_f,
          pass_rate:      t.pass_rate.to_f
        }
      },
      recent_attempts: recent.map { |a|
        {
          test_slug:  a.test_slug,
          score:      a.score.to_f,
          completed_at: a.completed_at
        }
      }
    }
  end
end
