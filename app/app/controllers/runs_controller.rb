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
      guest_token:     current_user ? nil : guest_token!,
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
      is_correct   = QuizGrading.correct?(question, selected_arr, challenge_mode)

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
      slug:                      t.slug,
      title:                     t.title,
      description:               t.description,
      tags:                      t.tag_list,
      difficulty:                t.difficulty,
      estimated_time:            t.estimated_time,
      questions_count:           t.questions_count,
      default_challenge_mode:    yaml["default_challenge_mode"],
      language:                  yaml["language"] || "ruby",
      completed_challenge_modes: current_user ? user_completed_modes(t.slug) : []
    }
  end

  def user_completed_modes(slug)
    return [] unless current_user
    TestAttempt
      .where(user_id: current_user.id, test_slug: slug)
      .where.not(challenge_mode: [ nil, "" ])
      .distinct
      .pluck(:challenge_mode)
  end

  def attempt_props(attempt)
    {
      id:              attempt.id,
      score:           attempt.score.to_f,
      correct_count:   attempt.correct_count,
      total_questions: attempt.total_questions,
      time_spent:      attempt.time_spent,
      completed_at:    attempt.completed_at,
      challenge_mode:  attempt.challenge_mode.presence
    }
  end

  def answers_detail(attempt, questions_map)
    challenge_mode = attempt.challenge_mode.presence || "fill"
    attempt.test_attempt_answers.filter_map do |ans|
      q = questions_map[ans.question_id]
      next unless q

      QuizGrading.answer_detail(q, ans.selected_options, ans.correct, challenge_mode)
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
