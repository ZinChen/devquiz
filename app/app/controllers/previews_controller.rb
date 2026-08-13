# Разовое прохождение теста из файла, который перетащили на список тестов.
# Определение теста живёт только в браузере: сюда оно приходит вместе с
# ответами, проверяется и отдаётся обратно разбором. В БД ничего не пишется —
# ни попытки, ни статистика теста.
class PreviewsController < ApplicationController
  # Определение приходит от клиента, а не из БД: явно проверяем структуру,
  # прежде чем что-либо по нему считать.
  before_action :load_definition, only: [ :create, :grade ]

  # Экран прохождения. Тест приходит POST-ом, потому что определение может быть
  # заметно больше, чем влезает в query string.
  def create
    render inertia: "Run/Preview", props: {
      test:      test_props,
      questions: questions_props
    }
  end

  def grade
    answers_data   = params[:answers]&.to_unsafe_h || {}
    challenge_mode = challenge_mode_param
    questions_map  = @definition["questions"].index_by { |q| q["id"] }

    details = answers_data.filter_map do |question_id, selected|
      question = questions_map[question_id]
      next unless question

      selected_arr = Array(selected)
      correct      = QuizGrading.correct?(question, selected_arr, challenge_mode)

      QuizGrading.answer_detail(question, selected_arr, correct, challenge_mode)
    end

    total         = @definition["questions"].size
    correct_count = details.count { |d| d[:correct] }
    score         = total > 0 ? (correct_count.to_f / total * 100).round(2) : 0
    has_code      = @definition["questions"].any? { |q| q["type"] == "code_challenge" }

    render json: {
      attempt: {
        score:           score,
        correct_count:   correct_count,
        total_questions: total,
        time_spent:      params[:time_spent].to_i,
        completed_at:    Time.current,
        # Режим кода показывается бейджем на результатах: без code_challenge
        # он ничего не значит и только сбивает с толку.
        challenge_mode:  has_code ? challenge_mode : nil
      },
      answers_detail: details
    }
  end

  private

  def load_definition
    result = QuizDefinition.validate(definition_param)

    unless result.valid?
      return render json: { errors: result.errors }, status: :unprocessable_entity
    end

    @definition = result.data
  end

  def definition_param
    raw = params[:test]
    raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw
  end

  def challenge_mode_param
    mode = params[:challenge_mode].presence
    QuizDefinition::CHALLENGE_MODES.include?(mode) ? mode : "fill"
  end

  def test_props
    @definition.slice("title", "description", "tags", "difficulty", "language")
      .merge(
        "slug"                      => nil,
        "estimated_time"            => @definition["estimated_time"],
        "questions_count"           => @definition["questions"].size,
        "default_challenge_mode"    => @definition["default_challenge_mode"],
        "completed_challenge_modes" => [],
        "preview"                   => true
      )
  end

  # db_id нет: закладки живут на вопросах из каталога, у разового теста их нет.
  def questions_props
    default_language = @definition["language"]
    @definition["questions"].map do |q|
      q.merge("language" => q["language"] || default_language)
    end
  end
end
