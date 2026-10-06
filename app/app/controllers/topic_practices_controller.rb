# Тренировка по слабой теме: вопросы, где пользователь ошибался, собранные
# по всем тестам сразу.
#
# Отдельно от RunsController: тот работает в границах одного теста (и пишет
# попытку с его slug), а здесь набор сквозной. Результат нигде не сохраняется
# — это тренировка, а не попытка: у вопросов разные тесты, и приписать её
# какому-то одному нельзя, не испортив его статистику.
#
# Интерфейс при этом общий с обычным прохождением: страница Topic/Practice
# собрана из тех же компонентов, что Run/New, а разбор рисует Run/Show.
# Поэтому и props здесь той же формы, что у RunsController.
class TopicPracticesController < ApplicationController
  QUESTIONS_LIMIT = 15

  def show
    topic = params[:topic].to_s
    return redirect_to dashboard_path, alert: "Неизвестная тема" unless TopicDictionary.known?(topic)

    questions = weak_questions_for(topic)
    return redirect_to dashboard_path, notice: "По этой теме нечего повторять" if questions.empty?

    render inertia: "Topic/Practice", props: {
      topic:          topic_props(topic),
      questions:      questions,
      bookmarked_ids: bookmarked_ids(questions)
    }
  end

  # Проверяет ответы и записывает их в историю: тренировка должна влиять на
  # слабые вопросы, иначе тема никогда не закроется. Попытки пишутся по одной
  # на каждый исходный тест — так они не искажают чужую статистику (в
  # update_test_stats такие попытки не идут вовсе).
  #
  # Ответы приходят от общего useQuizSession в виде { uid => [выбранное] },
  # где uid — ключ из #show: внутри темы ключом может быть только он, см.
  # question_uid.
  def grade
    topic = params[:topic].to_s
    return head :not_found unless TopicDictionary.known?(topic)

    answers = params[:answers]&.to_unsafe_h || {}
    by_test = TopicIndex.question_ids_for(topic)

    cache    = {}
    db_ids   = {}
    details  = []
    answered = Hash.new { |h, k| h[k] = [] }

    answers.each do |uid, selected|
      test_slug, question_id = uid.to_s.split(":", 2)
      # Слаг приехал с клиента, поэтому сверяем пару с индексом темы: иначе
      # ответ можно было бы записать в историю произвольного теста.
      next unless by_test[test_slug]&.include?(question_id)

      questions = cache[test_slug] ||=
        YamlSyncService.load_questions(test_slug).index_by { |q| q["id"] }
      question = questions[question_id]
      next unless question

      selected = Array(selected)
      correct  = QuizGrading.correct?(question, selected, "fill")
      db_map   = db_ids[test_slug] ||= Question.where(test_slug: test_slug).pluck(:question_id, :id).to_h

      answered[test_slug] << { question_id: question_id, selected: selected, correct: correct }
      details << QuizGrading
        .answer_detail(question, selected, correct, "fill", db_id: db_map[question_id])
        .merge(uid: uid, test_slug: test_slug)
    end

    record_attempts(answered)

    titles        = test_titles(details.map { |d| d[:test_slug] })
    correct_count = details.count { |d| d[:correct] }

    render json: {
      # Форма попытки — как в RunsController#attempt_props: разбор рисуется
      # тем же компонентом. Записи в БД за ней нет, поэтому и id нет.
      attempt: {
        score:           details.any? ? (correct_count.to_f / details.size * 100).round(2) : 0,
        correct_count:   correct_count,
        total_questions: details.size,
        time_spent:      params[:time_spent].to_i,
        challenge_mode:  nil
      },
      answers_detail: details.map { |d| d.merge(test_title: titles[d[:test_slug]]) }
    }
  end

  private

  # Одна попытка на тест — она нужна только чтобы ответы попали в
  # test_attempt_answers и учлись в WeakQuestions.
  def record_attempts(by_test)
    by_test.each do |test_slug, answers|
      attempt = TestAttempt.create!(
        user_id:         current_user&.id,
        guest_token:     current_user ? nil : guest_token!,
        test_slug:       test_slug,
        total_questions: answers.size,
        correct_count:   answers.count { |a| a[:correct] },
        started_at:      Time.current,
        completed_at:    Time.current,
        time_spent:      0,
        challenge_mode:  "fill"
      )

      answers.each do |answer|
        attempt.test_attempt_answers.create!(
          question_id:      answer[:question_id],
          selected_options: answer[:selected],
          correct:          answer[:correct]
        )
      end
    end
  end

  # Сквозной ключ вопроса в тренировке. Идентификаторы из YAML уникальны
  # только внутри теста (q1 есть почти везде), а здесь в одном наборе
  # вопросы из разных тестов: на голом id два разных вопроса делили бы и
  # слот ответа на клиенте, и строку разбора.
  def question_uid(test_slug, question_id)
    "#{test_slug}:#{question_id}"
  end

  def test_titles(slugs)
    TestMetadatum.where(slug: slugs.uniq).pluck(:slug, :title).to_h
  end

  def bookmarked_ids(questions)
    return [] unless current_user

    db_ids = questions.filter_map { |q| q["db_id"] }
    return [] if db_ids.empty?

    current_user.bookmarks.where(question_id: db_ids).pluck(:question_id)
  end

  def topic_props(slug)
    entry = TopicDictionary.find(slug)
    { slug: slug, label: entry&.label || slug, description: entry&.description, color: entry&.color }
  end

  # Слабые вопросы пользователя, оставляем только относящиеся к теме.
  # Тексты берём из YAML — там же, где живут сами topics.
  def weak_questions_for(topic)
    by_test = TopicIndex.question_ids_for(topic)
    return [] if by_test.empty?

    weak = WeakQuestions.for(user: current_user, guest_token: guest_token).entries
    return [] if weak.empty?

    cache = {}
    dbs   = {}

    picked = weak.filter_map { |entry|
      next unless by_test[entry.test_slug]&.include?(entry.question_id)

      questions = cache[entry.test_slug] ||=
        YamlSyncService.load_questions(entry.test_slug).index_by { |q| q["id"] }
      question = questions[entry.question_id]
      next unless question && question["type"] != "code_challenge"

      db_map = dbs[entry.test_slug] ||= Question.where(test_slug: entry.test_slug).pluck(:question_id, :id).to_h

      question.merge(
        "uid"       => question_uid(entry.test_slug, entry.question_id),
        "test_slug" => entry.test_slug,
        "db_id"     => db_map[entry.question_id]
      )
    }.first(QUESTIONS_LIMIT)

    titles = test_titles(picked.map { |q| q["test_slug"] })
    picked.map { |q| q.merge("test_title" => titles[q["test_slug"]] || q["test_slug"]) }
  end
end
