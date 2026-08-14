class RunsController < ApplicationController
  before_action :load_test

  def new
    questions = questions_with_db_ids
    weak_only = params[:only] == "weak"

    # Работа над ошибками: тот же тест, но только из слабых вопросов. Если
    # прорабатывать уже нечего, молча ведём обычное прохождение целиком.
    if weak_only
      weak_ids  = weak_questions(test_slug: @meta.slug).question_ids.to_set
      filtered  = questions.select { |q| weak_ids.include?(q["id"].to_s) }
      questions = filtered if filtered.any?
      weak_only = filtered.any?
    end

    bookmarked_ids = current_user ? current_user.bookmarks
      .joins(:question)
      .where(questions: { test_slug: @meta.slug })
      .pluck(:question_id) : []

    render inertia: "Run/New", props: {
      test:          test_props(@meta),
      questions:     questions,
      bookmarked_ids: bookmarked_ids,
      weak_only:     weak_only
    }
  end

  def create
    answers_data    = params[:answers].to_unsafe_h
    used_hint_ids   = Array(params[:used_hints]).map(&:to_s).to_set
    challenge_mode  = params[:challenge_mode].presence || "fill"

    # В работе над ошибками проходится подмножество вопросов, поэтому знаменатель
    # берётся по фактически заданным, а не по размеру теста — иначе 100% верных
    # ответов дали бы score вроде 25%.
    weak_only       = params[:weak_only].to_s == "true"
    total_questions = weak_only ? answers_data.size : @meta.questions_count

    attempt = TestAttempt.create!(
      user_id:         current_user&.id,
      guest_token:     current_user ? nil : guest_token!,
      test_slug:       @meta.slug,
      total_questions: total_questions,
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

    score = total_questions > 0 ? (correct_count.to_f / total_questions * 100).round(2) : 0

    attempt.update!(correct_count: correct_count, score: score)
    # Разбор ошибок — это тренировка по неполному тесту, в общую статистику
    # и в рекорд теста такие попытки не идут.
    update_test_stats(@meta, score, attempt) unless weak_only

    redirect_to test_run_path(test_slug: @meta.slug, id: attempt.id)
  end

  def show
    attempt = TestAttempt.includes(:test_attempt_answers).find(params[:id])
    questions_map = load_questions.index_by { |q| q["id"] }

    render inertia: "Run/Show", props: {
      test:           test_props(@meta),
      attempt:        attempt_props(attempt),
      answers_detail: answers_detail(attempt, questions_map),
      weak_topics:    weak_topics(attempt, questions_map)
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

  RECOMMENDED_TESTS_PER_TAG = 3
  WEAK_QUESTIONS_LIMIT      = 5

  # Слабые темы считаются по неверно отвеченным вопросам. Часть вопросов
  # размечена полем topics (mvc, indexes, locking…) — оно точнее и идёт
  # первым; для неразмеченных остаются теги теста целиком.
  def weak_topics(attempt, questions_map)
    wrong_ids = attempt.test_attempt_answers.reject(&:correct).map(&:question_id)
    return blank_weak_topics if wrong_ids.empty?

    # topics вопроса (mvc, indexes) точнее тегов теста (ruby, rails), но
    # размечены не везде и в tags тестов не встречаются — поэтому показываем
    # их, а тесты ищем по обоим наборам сразу.
    question_topics = wrong_ids.flat_map { |id| Array(questions_map[id]&.fetch("topics", nil)) }.map(&:to_s).uniq
    shown_tags      = question_topics.presence || @meta.tag_list
    search_tags     = (question_topics + @meta.tag_list).uniq
    return blank_weak_topics if search_tags.empty?

    {
      tags:                  TopicDictionary.decorate(shown_tags).map { |t| t.to_h },
      recommended_tests:     recommended_tests(search_tags),
      recent_mistakes:       recent_mistakes(questions_map),
      has_weak_in_this_test: weak_questions(test_slug: @meta.slug).any?
    }
  end

  def blank_weak_topics
    { tags: [], recommended_tests: [], recent_mistakes: [], has_weak_in_this_test: false }
  end

  def recommended_tests(search_tags)
    tag_conditions = search_tags.map { "tags LIKE ?" }.join(" OR ")
    tag_values     = search_tags.map { |t| "%#{t}%" }

    TestMetadatum.active
      .where.not(slug: @meta.slug)
      .where(tag_conditions, *tag_values)
      .limit(RECOMMENDED_TESTS_PER_TAG * 2)
      .map { |t| { slug: t.slug, title: t.title, tags: t.tag_list & search_tags } }
      .select { |t| t[:tags].any? }
      .first(RECOMMENDED_TESTS_PER_TAG)
  end

  # Вопросы, которые стоит проработать — см. WeakQuestions: учитываются
  # только недавние попытки, решённые вопросы из списка уходят.
  def recent_mistakes(questions_map)
    questions_cache = { @meta.slug => questions_map }

    weak_questions.entries.first(WEAK_QUESTIONS_LIMIT).map do |entry|
      cache = questions_cache[entry.test_slug] ||= YamlSyncService.load_questions(entry.test_slug).index_by { |q| q["id"] }
      text  = cache[entry.question_id]&.fetch("text", nil) || entry.question_id

      {
        question_id: entry.question_id,
        test_slug:   entry.test_slug,
        text:        text.to_s.truncate(140),
        wrong_count: entry.wrong_count
      }
    end
  end

  def weak_questions(test_slug: nil)
    WeakQuestions.for(user: current_user, guest_token: guest_token, test_slug: test_slug)
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
