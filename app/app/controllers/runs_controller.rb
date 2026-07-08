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
        original_code   = mode_data["code"]
        correct_answer  = Array(mode_data["answer"]).first || mode_data["correct_lines"]&.join(",")
        selected_answer = ans.selected_options.first.to_s

        if challenge_mode == "fix"
          base.merge(
            challenge_mode:  challenge_mode,
            code:            original_code,
            language:        q["language"] || "ruby",
            correct_answer:  diff_lines(original_code, correct_answer),
            insert_text:     mode_data["insert_text"],
            selected_answer: diff_lines(original_code, selected_answer)
          )
        else
          base.merge(
            challenge_mode:  challenge_mode,
            code:            original_code,
            language:        q["language"] || "ruby",
            correct_answer:  correct_answer,
            insert_text:     mode_data["insert_text"],
            selected_answer: selected_answer
          )
        end
      else
        base.merge(
          options:          q["options"].map { |o| o.slice("id", "text", "explanation") },
          correct_ids:      q["options"].select { |o| o["correct"] }.map { |o| o["id"] },
          selected_options: ans.selected_options
        )
      end
    end.compact
  end

  # Line-based diff between `original` and `changed` using LCS. Returns only
  # the lines of `changed` that differ from `original` (no unchanged
  # context), each as a line of tokens: { text:, changed: true|false }.
  # Lines that replace a removed original line get a word-level diff so only
  # the changed words are marked; purely new lines are marked as a whole.
  def diff_lines(original, changed)
    original_lines = original.to_s.split("\n", -1)
    changed_lines   = changed.to_s.split("\n", -1)

    lcs = longest_common_subsequence(original_lines, changed_lines)

    removed_runs = []
    added_lines  = []
    oi = 0
    ci = 0
    lcs.each do |line|
      run_removed = []
      while oi < original_lines.size && original_lines[oi] != line
        run_removed << original_lines[oi]
        oi += 1
      end
      run_added = []
      while ci < changed_lines.size && changed_lines[ci] != line
        run_added << changed_lines[ci]
        ci += 1
      end
      removed_runs << run_removed unless run_removed.empty?
      added_lines.concat(pair_changed_lines(run_removed, run_added))
      oi += 1
      ci += 1
    end

    run_removed = []
    while oi < original_lines.size
      run_removed << original_lines[oi]
      oi += 1
    end
    run_added = []
    while ci < changed_lines.size
      run_added << changed_lines[ci]
      ci += 1
    end
    added_lines.concat(pair_changed_lines(run_removed, run_added))

    added_lines
  end

  # Within a run of consecutive removed/added lines, pairs up removed[i]
  # with added[i] (line replacement) and returns a word-level diff for each
  # pair; leftover added lines with no counterpart are marked as a whole.
  def pair_changed_lines(removed, added)
    added.each_with_index.map do |line, idx|
      if idx < removed.size
        word_diff_tokens(removed[idx], line)
      else
        [ { text: line, changed: true } ]
      end
    end
  end

  def word_diff_tokens(original_line, changed_line)
    original_words = original_line.split(/(\s+)/)
    changed_words   = changed_line.split(/(\s+)/)
    lcs = longest_common_subsequence(original_words, changed_words)

    tokens = []
    oi = 0
    ci = 0
    lcs.each do |word|
      oi += 1 while oi < original_words.size && original_words[oi] != word
      while ci < changed_words.size && changed_words[ci] != word
        tokens << { text: changed_words[ci], changed: true }
        ci += 1
      end
      tokens << { text: word, changed: false }
      oi += 1
      ci += 1
    end
    while ci < changed_words.size
      tokens << { text: changed_words[ci], changed: true }
      ci += 1
    end

    tokens
  end

  def longest_common_subsequence(a, b)
    n = a.size
    m = b.size
    dp = Array.new(n + 1) { Array.new(m + 1, 0) }

    (n - 1).downto(0) do |i|
      (m - 1).downto(0) do |j|
        dp[i][j] = a[i] == b[j] ? dp[i + 1][j + 1] + 1 : [ dp[i + 1][j], dp[i][j + 1] ].max
      end
    end

    result = []
    i = 0
    j = 0
    while i < n && j < m
      if a[i] == b[j]
        result << a[i]
        i += 1
        j += 1
      elsif dp[i + 1][j] >= dp[i][j + 1]
        i += 1
      else
        j += 1
      end
    end
    result
  end

  def grade_code_challenge(question, selected_arr, mode)
    mode_data = question.dig("modes", mode) || {}
    case mode
    when "highlight"
      correct_raw = Array(mode_data["correct_lines"]).map(&:to_s)
      selected    = selected_arr.first.to_s.split(",").map(&:strip).sort

      # build all accepted forms for each correct entry:
      # "after:N" also accepts line N (the line before the gap)
      # plain line number N also accepts "after:N-1"
      accepted = correct_raw.flat_map do |c|
        if c.start_with?("after:")
          n = c.sub("after:", "").to_i
          [ c, n.to_s ]
        else
          n = c.to_i
          [ c, "after:#{n - 1}" ]
        end
      end

      selected.all? { |s| accepted.include?(s) } &&
        selected.size == correct_raw.size
    when "fix"
      normalize = ->(s) { s.to_s.lines.map(&:rstrip).reject(&:empty?).join("\n").strip }
      normalize.(selected_arr.first) == normalize.(mode_data["answer"])
    else
      accepted = Array(mode_data["answer"]).map { |a| a.to_s.strip.downcase }
      accepted.include?(selected_arr.first.to_s.strip.downcase)
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
