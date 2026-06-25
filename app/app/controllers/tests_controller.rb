class TestsController < ApplicationController
  def index
    tests_list = TestMetadatum.active.order(attempts_count: :desc).to_a
    total = tests_list.size
    tag_counts = tests_list.flat_map(&:tag_list).tally
    visible_tags = tag_counts
      .reject { |_, count| count == total }
      .sort_by { |_, count| -count }
      .map(&:first)

    render inertia: "Tests/Index", props: {
      tests:    tests_list.map { |t| test_props(t) },
      all_tags: visible_tags
    }
  end

  def show
    test = TestMetadatum.find_by!(slug: params[:slug])
    render inertia: "Tests/Show", props: { test: test_props(test) }
  end

  private

  def test_props(t)
    {
      slug:           t.slug,
      title:          t.title,
      description:    t.description,
      tags:           t.tag_list,
      difficulty:     t.difficulty,
      estimated_time: t.estimated_time,
      questions_count: t.questions_count,
      attempts_count:  t.attempts_count,
      avg_score:       t.avg_score.to_f,
      pass_rate:       t.pass_rate.to_f,
      best_score:      t.best_score&.to_f,
      best_attempt_id: t.best_attempt_id
    }
  end
end
