require 'rails_helper'

RSpec.describe QuizDefinition do
  def definition(overrides = {})
    {
      "title" => "Дропнутый тест",
      "questions" => [
        {
          "id" => "q1",
          "text" => "Вопрос?",
          "type" => "single",
          "options" => [
            { "id" => "a", "text" => "Нет", "correct" => false },
            { "id" => "b", "text" => "Да",  "correct" => true }
          ]
        }
      ]
    }.merge(overrides)
  end

  describe "валидная структура" do
    it "принимает минимальный тест" do
      result = described_class.validate(definition)

      expect(result).to be_valid
      expect(result.data["title"]).to eq("Дропнутый тест")
      expect(result.data["questions"].size).to eq(1)
    end

    it "подставляет slug и язык по умолчанию" do
      result = described_class.validate(definition)

      expect(result.data["slug"]).to eq("preview")
      expect(result.data["language"]).to eq("ruby")
    end

    it "проставляет id вопросам без него" do
      raw = definition
      raw["questions"][0].delete("id")

      expect(described_class.validate(raw).data["questions"][0]["id"]).to eq("q1")
    end

    it "отбрасывает difficulty вне словаря" do
      expect(described_class.validate(definition("difficulty" => "нормальная")).data["difficulty"]).to be_nil
      expect(described_class.validate(definition("difficulty" => "advanced")).data["difficulty"]).to eq("advanced")
    end
  end

  describe "невалидная структура" do
    it "отклоняет не-объект" do
      expect(described_class.validate([ 1, 2 ])).not_to be_valid
      expect(described_class.validate("строка")).not_to be_valid
    end

    it "требует title" do
      result = described_class.validate(definition("title" => ""))

      expect(result).not_to be_valid
      expect(result.errors).to include(/title/)
    end

    it "требует непустой список вопросов" do
      expect(described_class.validate(definition("questions" => []))).not_to be_valid
      expect(described_class.validate(definition("questions" => nil))).not_to be_valid
    end

    it "требует хотя бы один правильный вариант" do
      raw = definition
      raw["questions"][0]["options"].each { |o| o["correct"] = false }

      result = described_class.validate(raw)

      expect(result).not_to be_valid
      expect(result.errors.first).to match(/правильн/)
    end

    it "требует options у обычного вопроса" do
      raw = definition
      raw["questions"][0].delete("options")

      expect(described_class.validate(raw)).not_to be_valid
    end

    it "отклоняет слишком много вопросов" do
      many = Array.new(described_class::MAX_QUESTIONS + 1) { |i| definition["questions"][0].merge("id" => "q#{i}") }

      expect(described_class.validate(definition("questions" => many))).not_to be_valid
    end
  end

  describe "code_challenge" do
    def code_question(modes)
      definition("questions" => [ {
        "id" => "c1", "text" => "Найди баг", "type" => "code_challenge", "modes" => modes
      } ])
    end

    it "принимает вопрос с одним режимом" do
      result = described_class.validate(code_question(
        "highlight" => { "code" => "puts 1", "correct_lines" => [ "after:1" ], "insert_text" => "  x" }
      ))

      expect(result).to be_valid
      expect(result.data["questions"][0]["modes"]["highlight"]["correct_lines"]).to eq([ "after:1" ])
    end

    it "требует блок modes" do
      expect(described_class.validate(code_question(nil))).not_to be_valid
      expect(described_class.validate(code_question({}))).not_to be_valid
    end

    it "требует code в режиме" do
      expect(described_class.validate(code_question("fill" => { "answer" => "x" }))).not_to be_valid
    end

    it "требует correct_lines для highlight" do
      expect(described_class.validate(code_question("highlight" => { "code" => "puts 1" }))).not_to be_valid
    end

    it "требует answer для остальных режимов" do
      expect(described_class.validate(code_question("fill" => { "code" => "___" }))).not_to be_valid
    end

    it "игнорирует неизвестные режимы" do
      result = described_class.validate(code_question(
        "highlight" => { "code" => "puts 1", "correct_lines" => [ "1" ] },
        "telepathy" => { "code" => "?" }
      ))

      expect(result).to be_valid
      expect(result.data["questions"][0]["modes"].keys).to eq([ "highlight" ])
    end
  end
end
