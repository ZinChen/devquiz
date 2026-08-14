# Валидация структуры теста, пришедшей извне (перетащенный .yml).
# Файл не из репозитория, поэтому доверять ему нельзя: проверяем форму,
# режем размеры и возвращаем нормализованный хэш либо список ошибок.
class QuizDefinition
  MAX_QUESTIONS   = 300
  MAX_OPTIONS     = 12
  MAX_TEXT_LENGTH = 20_000
  DIFFICULTIES    = %w[beginner intermediate advanced].freeze
  QUESTION_TYPES  = %w[single multiple code_challenge].freeze
  CHALLENGE_MODES = %w[highlight select fill fix].freeze

  attr_reader :errors, :data

  def self.validate(raw)
    new(raw).tap(&:validate)
  end

  def initialize(raw)
    @raw    = raw
    @errors = []
    @data   = nil
  end

  def valid?
    errors.empty?
  end

  def validate
    unless @raw.is_a?(Hash)
      return error("Файл должен содержать объект с полями теста")
    end

    title     = string_field("title")
    questions = @raw["questions"]

    error("Не заполнено поле title") if title.blank?

    unless questions.is_a?(Array) && questions.any?
      error("Не найдено ни одного вопроса в поле questions")
      return self
    end

    if questions.size > MAX_QUESTIONS
      error("Слишком много вопросов: #{questions.size} (максимум #{MAX_QUESTIONS})")
      return self
    end

    validated = questions.each_with_index.map { |q, i| validate_question(q, i) }
    return self unless valid?

    @data = {
      "slug"                   => string_field("slug").presence || "preview",
      "title"                  => title,
      "description"            => string_field("description"),
      "tags"                   => Array(@raw["tags"]).map(&:to_s).first(20),
      "difficulty"             => DIFFICULTIES.include?(@raw["difficulty"]) ? @raw["difficulty"] : nil,
      "estimated_time"         => @raw["estimated_time"].to_i.clamp(0, 600),
      "language"               => string_field("language").presence || "ruby",
      "default_challenge_mode" => CHALLENGE_MODES.include?(@raw["default_challenge_mode"]) ? @raw["default_challenge_mode"] : nil,
      "questions"              => validated
    }

    self
  end

  private

  def validate_question(q, index)
    label = "Вопрос ##{index + 1}"

    unless q.is_a?(Hash)
      error("#{label}: ожидается объект с полями вопроса")
      return nil
    end

    id   = q["id"].to_s.presence || "q#{index + 1}"
    text = q["text"].to_s
    type = QUESTION_TYPES.include?(q["type"]) ? q["type"] : "single"

    error("#{label}: пустой текст вопроса") if text.blank?
    error("#{label}: текст длиннее #{MAX_TEXT_LENGTH} символов") if text.length > MAX_TEXT_LENGTH

    base = {
      "id"                   => id,
      "text"                 => truncate(text),
      "type"                 => type,
      "explanation"          => truncate(q["explanation"].to_s).presence,
      "extended_explanation" => truncate(q["extended_explanation"].to_s).presence,
      "recommendation"       => truncate(q["recommendation"].to_s).presence,
      "difficulty"           => q["difficulty"].to_s.presence,
      "language"             => q["language"].to_s.presence,
      "topics"               => Array(q["topics"]).map(&:to_s).first(10)
    }

    type == "code_challenge" ? base.merge(validate_modes(q, label)) : base.merge(validate_options(q, label))
  end

  def validate_options(q, label)
    options = q["options"]

    unless options.is_a?(Array) && options.any?
      error("#{label}: нужен непустой список options")
      return { "options" => [] }
    end

    if options.size > MAX_OPTIONS
      error("#{label}: слишком много вариантов (максимум #{MAX_OPTIONS})")
      return { "options" => [] }
    end

    unless options.all? { |o| o.is_a?(Hash) }
      error("#{label}: каждый вариант должен быть объектом с полями id/text/correct")
      return { "options" => [] }
    end

    if options.none? { |o| truthy?(o["correct"]) }
      error("#{label}: не отмечен ни один правильный вариант (correct: true)")
    end

    {
      "options" => options.each_with_index.map do |o, i|
        {
          "id"          => o["id"].to_s.presence || ("a".ord + i).chr,
          "text"        => truncate(o["text"].to_s),
          "correct"     => truthy?(o["correct"]),
          "explanation" => truncate(o["explanation"].to_s).presence
        }.compact
      end
    }
  end

  # Для code_challenge проверяем только те режимы, что реально описаны в файле:
  # прохождение идёт в одном режиме, и требовать все четыре незачем.
  def validate_modes(q, label)
    modes = q["modes"]

    unless modes.is_a?(Hash) && modes.slice(*CHALLENGE_MODES).any?
      error("#{label}: для code_challenge нужен блок modes хотя бы с одним из режимов: #{CHALLENGE_MODES.join(', ')}")
      return { "modes" => {} }
    end

    validated = modes.slice(*CHALLENGE_MODES).filter_map do |name, body|
      unless body.is_a?(Hash)
        error("#{label}: режим #{name} должен быть объектом")
        next
      end

      if body["code"].to_s.blank?
        error("#{label}: в режиме #{name} не задано поле code")
        next
      end

      if name == "highlight" && Array(body["correct_lines"]).empty?
        error("#{label}: в режиме highlight не заданы correct_lines")
        next
      end

      if name != "highlight" && Array(body["answer"]).empty?
        error("#{label}: в режиме #{name} не задано поле answer")
        next
      end

      [ name, {
        "code"          => truncate(body["code"].to_s),
        "answer"        => Array(body["answer"]).map { |a| truncate(a.to_s) },
        "correct_lines" => Array(body["correct_lines"]).map(&:to_s),
        "insert_text"   => body["insert_text"].to_s.presence,
        "prefill"       => body["prefill"].to_s.presence,
        "hint"          => truncate(body["hint"].to_s).presence
      }.compact ]
    end.to_h

    { "modes" => validated }
  end

  def truthy?(value)
    value == true || value.to_s.casecmp("true").zero?
  end

  def string_field(key)
    @raw[key].is_a?(String) ? @raw[key] : @raw[key].to_s
  end

  def truncate(str)
    str.length > MAX_TEXT_LENGTH ? str[0, MAX_TEXT_LENGTH] : str
  end

  def error(message)
    @errors << message
    self
  end
end
