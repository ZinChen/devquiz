# Тренировка по слабой теме: вопросы, где пользователь ошибался, собранные
# по всем тестам сразу.
#
# Отдельно от RunsController: тот работает в границах одного теста (и пишет
# попытку с его slug), а здесь набор сквозной. Результат нигде не сохраняется
# — это тренировка, а не попытка: у вопросов разные тесты, и приписать её
# какому-то одному нельзя, не испортив его статистику.
class TopicPracticesController < ApplicationController
  QUESTIONS_LIMIT = 15

  def show
    topic = params[:topic].to_s
    return redirect_to dashboard_path, alert: "Неизвестная тема" unless TopicDictionary.known?(topic)

    questions = weak_questions_for(topic)
    return redirect_to dashboard_path, notice: "По этой теме нечего повторять" if questions.empty?

    render inertia: "Topic/Practice", props: {
      topic:     topic_props(topic),
      questions: questions
    }
  end

  # Проверяет ответы и записывает их в историю: тренировка должна влиять на
  # слабые вопросы, иначе тема никогда не закроется. Попытки пишутся по одной
  # на каждый исходный тест — так они не искажают чужую статистику (в
  # update_test_stats такие попытки не идут вовсе).
  def grade
    topic = params[:topic].to_s
    return head :not_found unless TopicDictionary.known?(topic)

    answers = params[:answers]&.to_unsafe_h || {}
    return render json: { details: [] } if answers.empty?

    cache   = {}
    details = []
    by_test = Hash.new { |h, k| h[k] = [] }

    answers.each do |question_id, payload|
      test_slug = payload["test_slug"].to_s
      selected  = Array(payload["selected"])
      next if test_slug.blank?

      questions = cache[test_slug] ||=
        YamlSyncService.load_questions(test_slug).index_by { |q| q["id"] }
      question = questions[question_id]
      next unless question

      correct = QuizGrading.correct?(question, selected, "fill")
      by_test[test_slug] << { question_id: question_id, selected: selected, correct: correct }
      details << QuizGrading.answer_detail(question, selected, correct, "fill").merge(test_slug: test_slug)
    end

    record_attempts(by_test)

    render json: {
      details:       details,
      correct_count: details.count { |d| d[:correct] },
      total:         details.size
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

    picked = weak.filter_map { |entry|
      next unless by_test[entry.test_slug]&.include?(entry.question_id)

      questions = cache[entry.test_slug] ||=
        YamlSyncService.load_questions(entry.test_slug).index_by { |q| q["id"] }
      question = questions[entry.question_id]
      next unless question && question["type"] != "code_challenge"

      question.merge("test_slug" => entry.test_slug)
    }.first(QUESTIONS_LIMIT)

    titles = TestMetadatum.where(slug: picked.map { |q| q["test_slug"] }.uniq).pluck(:slug, :title).to_h
    picked.map { |q| q.merge("test_title" => titles[q["test_slug"]] || q["test_slug"]) }
  end
end
