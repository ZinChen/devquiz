# Проверка ответов и построение разбора. Вынесено из RunsController, чтобы
# сохранённые прохождения и разовые тесты из перетащенного файла
# (PreviewsController) судились ровно по одним и тем же правилам.
module QuizGrading
  module_function

  def correct?(question, selected_arr, challenge_mode)
    if question["type"] == "code_challenge"
      grade_code_challenge(question, selected_arr, challenge_mode)
    else
      correct_ids = question["options"].to_a.select { |o| o["correct"] }.map { |o| o["id"] }
      selected_arr.sort == correct_ids.sort
    end
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

  # Разбор одного ответа для страницы результатов. `selected_options` —
  # массив выбранного, `correct` — уже посчитанный вердикт.
  def answer_detail(question, selected_options, correct, challenge_mode)
    base = {
      question_id:          question["id"],
      question_text:        question["text"],
      type:                 question["type"].presence || "single",
      correct:              correct,
      explanation:          question["explanation"],
      extended_explanation: question["extended_explanation"].presence,
      recommendation:       question["recommendation"].presence
    }

    return base.merge(choice_detail(question, selected_options)) unless question["type"] == "code_challenge"

    base.merge(code_detail(question, selected_options, challenge_mode))
  end

  def choice_detail(question, selected_options)
    {
      options:          question["options"].to_a.map { |o| o.slice("id", "text", "explanation") },
      correct_ids:      question["options"].to_a.select { |o| o["correct"] }.map { |o| o["id"] },
      selected_options: selected_options
    }
  end

  def code_detail(question, selected_options, challenge_mode)
    mode_data       = question.dig("modes", challenge_mode) || {}
    original_code   = mode_data["code"]
    correct_answer  = Array(mode_data["answer"]).first || mode_data["correct_lines"]&.join(",")
    selected_answer = selected_options.first.to_s

    common = {
      challenge_mode: challenge_mode,
      code:           original_code,
      language:       question["language"] || "ruby",
      insert_text:    mode_data["insert_text"]
    }

    if challenge_mode == "fix"
      common.merge(
        correct_answer:  diff_lines(original_code, correct_answer),
        selected_answer: diff_lines(original_code, selected_answer)
      )
    else
      common.merge(
        correct_answer:  correct_answer,
        selected_answer: selected_answer
      )
    end
  end

  # Line-based diff between `original` and `changed` using LCS. Returns only
  # the lines that differ (no unchanged context), each either:
  #   { kind: "removed", content: }         — a line only `original` had
  #   { kind: "modified", tokens: [{text:, type: "context"|"added"}] } — a
  #     line of `changed`, word-diffed against its removed counterpart when
  #     replacing one line for one line; words unique to `changed` are
  #     tagged type: "added".
  def diff_lines(original, changed)
    original_lines = original.to_s.split("\n", -1)
    changed_lines   = changed.to_s.split("\n", -1)

    lcs = longest_common_subsequence(original_lines, changed_lines)

    result = []
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
      result.concat(diff_run(run_removed, run_added))
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
    result.concat(diff_run(run_removed, run_added))

    result.reject { |line| line[:kind] == "modified" && line[:tokens].none? { |t| t[:type] == "added" } }
  end

  # Within a run of consecutive removed/added lines, pairs up removed[i]
  # with added[i] (line replacement) and returns a word-level diff for each
  # pair; leftover removed lines are kept as whole "removed" lines, leftover
  # added lines with no counterpart are marked as a whole "modified" line.
  def diff_run(removed, added)
    paired = [ removed.size, added.size ].min
    lines  = (0...paired).map { |i| { kind: "modified", tokens: word_diff_tokens(removed[i], added[i]) } }
    lines += removed[paired..].to_a.map { |line| { kind: "removed", content: line } }
    lines += added[paired..].to_a.map { |line|
      type = line.strip.empty? ? "context" : "added"
      { kind: "modified", tokens: [ { text: line, type: type } ] }
    }
    lines
  end

  # Splits a line into words, runs of whitespace, and individual punctuation
  # characters, so a diff at a single identifier (e.g. find_each -> in_batches)
  # doesn't drag along neighbouring parens/colons into the "added" tokens.
  WORD_TOKEN_PATTERN = /[a-zA-Z0-9_]+|\s+|./

  def word_diff_tokens(original_line, changed_line)
    original_words = original_line.scan(WORD_TOKEN_PATTERN)
    changed_words   = changed_line.scan(WORD_TOKEN_PATTERN)
    lcs = longest_common_subsequence(original_words, changed_words)

    tokens = []
    oi = 0
    ci = 0
    lcs.each do |word|
      oi += 1 while oi < original_words.size && original_words[oi] != word
      while ci < changed_words.size && changed_words[ci] != word
        tokens << { text: changed_words[ci], type: added_token_type(changed_words[ci]) }
        ci += 1
      end
      tokens << { text: word, type: "context" }
      oi += 1
      ci += 1
    end
    while ci < changed_words.size
      tokens << { text: changed_words[ci], type: added_token_type(changed_words[ci]) }
      ci += 1
    end

    tokens
  end

  def added_token_type(text)
    text.strip.empty? ? "context" : "added"
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
end
