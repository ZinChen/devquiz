class RunsController < ApplicationController
  before_action :load_test

  def new
    questions = questions_with_db_ids
    bookmarked_ids = current_user ? current_user.bookmarks
      .joins(:question)
      .where(questions: { test_slug: @meta.slug })
      .pluck(:question_id) : []

    render inertia: "Run/New", props: {
      test:          test_props(@meta),
      questions:     questions,
      bookmarked_ids: bookmarked_ids
    }
  end

  def create
    answers_data = params[:answers].to_unsafe_h

    attempt = TestAttempt.create!(
      user_id:         current_user&.id,
      test_slug:       @meta.slug,
      total_questions: @meta.questions_count,
      started_at:      Time.parse(params[:started_at]),
      completed_at:    Time.current,
      time_spent:      params[:time_spent].to_i
    )

    questions_map = load_questions.index_by { |q| q["id"] }
    correct_count = 0

    answers_data.each do |question_id, selected|
      question     = questions_map[question_id]
      next unless question

      selected_arr = Array(selected)
      correct_ids  = question["options"].select { |o| o["correct"] }.map { |o| o["id"] }
      is_correct   = selected_arr.sort == correct_ids.sort

      correct_count += 1 if is_correct

      attempt.test_attempt_answers.create!(
        question_id:      question_id,
        selected_options: selected_arr,
        correct:          is_correct
      )
    end

    score = @meta.questions_count > 0 ? (correct_count.to_f / @meta.questions_count * 100).round(2) : 0

    attempt.update!(correct_count: correct_count, score: score)
    update_test_stats(@meta, score, attempt)

    redirect_to test_run_path(test_slug: @meta.slug, id: attempt.id)
  end

  def show
    attempt = TestAttempt.includes(:test_attempt_answers).find(params[:id])
    questions_map = load_questions.index_by { |q| q["id"] }

    render inertia: "Run/Show", props: {
      test:           test_props(@meta),
      attempt:        attempt_props(attempt),
      answers_detail: answers_detail(attempt, questions_map)
    }
  end

  private

  def load_test
    @meta = TestMetadatum.find_by!(slug: params[:test_slug])
  end

  def load_questions
    @questions ||= YamlSyncService.load_questions(@meta.slug)
  end

  def questions_with_db_ids
    db_map = Question.where(test_slug: @meta.slug).index_by(&:question_id)
    load_questions.map do |q|
      db_rec = db_map[q["id"].to_s]
      q.merge("db_id" => db_rec&.id)
    end
  end

  def test_props(t)
    {
      slug:            t.slug,
      title:           t.title,
      description:     t.description,
      tags:            t.tag_list,
      difficulty:      t.difficulty,
      estimated_time:  t.estimated_time,
      questions_count: t.questions_count
    }
  end

  def attempt_props(attempt)
    {
      id:              attempt.id,
      score:           attempt.score.to_f,
      correct_count:   attempt.correct_count,
      total_questions: attempt.total_questions,
      time_spent:      attempt.time_spent,
      completed_at:    attempt.completed_at
    }
  end

  def answers_detail(attempt, questions_map)
    attempt.test_attempt_answers.map do |ans|
      q = questions_map[ans.question_id]
      next unless q
      {
        question_id:          ans.question_id,
        question_text:        q["text"],
        options:              q["options"].map { |o| o.slice("id", "text", "explanation") },
        correct_ids:          q["options"].select { |o| o["correct"] }.map { |o| o["id"] },
        selected_options:     ans.selected_options,
        correct:              ans.correct,
        explanation:          q["explanation"],
        extended_explanation: q["extended_explanation"].presence,
        recommendation:       q["recommendation"].presence
      }
    end.compact
  end

  def update_test_stats(meta, new_score, attempt)
    total     = meta.attempts_count.to_i + 1
    new_avg   = ((meta.avg_score.to_f * meta.attempts_count.to_i) + new_score) / total
    passing   = TestAttempt.where(test_slug: meta.slug).where("score >= 70").count
    pass_rate = (passing.to_f / total * 100).round(2)

    is_best = meta.best_score.nil? || new_score > meta.best_score.to_f

    meta.update!(
      attempts_count: total,
      avg_score:      new_avg.round(2),
      pass_rate:      pass_rate,
      best_score:     is_best ? new_score : meta.best_score,
      best_attempt_id: is_best ? attempt.id : meta.best_attempt_id
    )
  end
end
