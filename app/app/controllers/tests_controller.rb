class TestsController < ApplicationController
  def index
    tag    = params[:tag]
    difficulty = params[:difficulty]

    tests = TestMetadatum.order(attempts_count: :desc)
    tests = tests.where("tags LIKE ?", "%#{tag}%") if tag.present?
    tests = tests.where(difficulty: difficulty) if difficulty.present?

    render inertia: "Tests/Index", props: {
      tests:      tests.map { |t| test_props(t) },
      all_tags:   TestMetadatum.all.flat_map(&:tag_list).tally.sort_by { |_, c| -c }.map(&:first),
      filter_tag: tag,
      filter_difficulty: difficulty
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
      attempts_count: t.attempts_count,
      avg_score:      t.avg_score.to_f,
      pass_rate:      t.pass_rate.to_f
    }
  end
end
