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
    answers_data    = params[:answers].to_unsafe_h
    used_hint_ids   = Array(params[:used_hints]).map(&:to_s).to_set
    challenge_mode  = params[:challenge_mode].presence || "fill"

    attempt = TestAttempt.create!(
      user_id:         current_user&.id,
      test_slug:       @meta.slug,
      total_questions: @meta.questions_count,
      started_at:      Time.parse(params[:started_at]),
      completed_at:    Time.current,
      time_spent:      params[:time_spent].to_i,
      challenge_mode:  challenge_mode
    )

    questions_map   = load_questions.index_by { |q| q["id"] }
    correct_count   = 0

    answers_data.each do |question_id, selected|
      question     = questions_map[question_id]
      next unless question

      selected_arr = Array(selected)
      is_correct   = if question["type"] == "code_challenge"
        grade_code_challenge(question, selected_arr, challenge_mode)
      else
        correct_ids = question["options"].select { |o| o["correct"] }.map { |o| o["id"] }
        selected_arr.sort == correct_ids.sort
      end

      correct_count += 1 if is_correct

      attempt.test_attempt_answers.create!(
        question_id:      question_id,
        selected_options: selected_arr,
        correct:          is_correct,
        used_hint:        used_hint_ids.include?(question_id)
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

  def meta_yaml(slug = @meta.slug)
    @meta_yaml ||= YAML.safe_load(
      File.read(YamlSyncService::TESTS_DIR.join("#{slug}.yml")),
      permitted_classes: [ Symbol ]
    ) rescue {}
  end

  def questions_with_db_ids
    db_map        = Question.where(test_slug: @meta.slug).index_by(&:question_id)
    test_language = meta_yaml["language"] || "ruby"
    load_questions.map do |q|
      db_rec = db_map[q["id"].to_s]
      q.merge("db_id" => db_rec&.id, "language" => q["language"] || test_language)
    end
  end

  def test_props(t)
    yaml = t.slug == @meta&.slug ? meta_yaml : (YAML.safe_load(
      File.read(YamlSyncService::TESTS_DIR.join("#{t.slug}.yml")),
      permitted_classes: [ Symbol ]
    ) rescue {})
    {
      slug:                   t.slug,
      title:                  t.title,
      description:            t.description,
      tags:                   t.tag_list,
      difficulty:             t.difficulty,
      estimated_time:         t.estimated_time,
      questions_count:        t.questions_count,
      default_challenge_mode: yaml["default_challenge_mode"],
      language:               yaml["language"] || "ruby"
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
    challenge_mode = attempt.challenge_mode.presence || "fill"
    attempt.test_attempt_answers.map do |ans|
      q = questions_map[ans.question_id]
      next unless q

      base = {
        question_id:          ans.question_id,
        question_text:        q["text"],
        type:                 q["type"].presence || "single",
        correct:              ans.correct,
        explanation:          q["explanation"],
        extended_explanation: q["extended_explanation"].presence,
        recommendation:       q["recommendation"].presence
      }

      if q["type"] == "code_challenge"
        mode_data = q.dig("modes", challenge_mode) || {}
        base.merge(
          challenge_mode:  challenge_mode,
          code:            mode_data["code"],
          correct_answer:  mode_data["answer"] || mode_data["correct_lines"]&.join(","),
          selected_answer: ans.selected_options.first.to_s
        )
      else
        base.merge(
          options:          q["options"].map { |o| o.slice("id", "text", "explanation") },
          correct_ids:      q["options"].select { |o| o["correct"] }.map { |o| o["id"] },
          selected_options: ans.selected_options
        )
      end
    end.compact
  end

  def grade_code_challenge(question, selected_arr, mode)
    mode_data = question.dig("modes", mode) || {}
    case mode
    when "highlight"
      correct  = Array(mode_data["correct_lines"]).map(&:to_s).sort
      selected = selected_arr.first.to_s.split(",").map(&:strip).sort
      selected == correct
    when "fix"
      normalize = ->(s) { s.to_s.lines.map(&:rstrip).reject(&:empty?).join("\n").strip }
      normalize.(selected_arr.first) == normalize.(mode_data["answer"])
    else
      selected_arr.first.to_s.strip.downcase == mode_data["answer"].to_s.strip.downcase
    end
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
