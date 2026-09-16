require 'rails_helper'

RSpec.describe QuizGrading do
  describe ".correct?" do
    let(:single) do
      {
        "id" => "q1", "type" => "single",
        "options" => [
          { "id" => "a", "text" => "нет", "correct" => false },
          { "id" => "b", "text" => "да",  "correct" => true }
        ]
      }
    end

    let(:multiple) do
      {
        "id" => "q2", "type" => "multiple",
        "options" => [
          { "id" => "a", "text" => "1", "correct" => true },
          { "id" => "b", "text" => "2", "correct" => false },
          { "id" => "c", "text" => "3", "correct" => true }
        ]
      }
    end

    it "сверяет одиночный выбор" do
      expect(described_class.correct?(single, [ "b" ], "fill")).to be true
      expect(described_class.correct?(single, [ "a" ], "fill")).to be false
      expect(described_class.correct?(single, [],      "fill")).to be false
    end

    it "требует полного совпадения при множественном выборе" do
      expect(described_class.correct?(multiple, [ "a", "c" ], "fill")).to be true
      expect(described_class.correct?(multiple, [ "c", "a" ], "fill")).to be true
      expect(described_class.correct?(multiple, [ "a" ],      "fill")).to be false
      expect(described_class.correct?(multiple, [ "a", "b", "c" ], "fill")).to be false
    end
  end

  describe ".grade_code_challenge" do
    let(:question) do
      {
        "type" => "code_challenge",
        "modes" => {
          "highlight" => { "code" => "a\nb\nc", "correct_lines" => [ "after:1" ] },
          "fill"      => { "code" => "___", "answer" => [ "disable_ddl_transaction!" ] },
          "fix"       => { "code" => "x = 1", "answer" => "x = 2" }
        }
      }
    end

    it "принимает обе формы записи строки в highlight" do
      expect(described_class.grade_code_challenge(question, [ "after:1" ], "highlight")).to be true
      expect(described_class.grade_code_challenge(question, [ "1" ],       "highlight")).to be true
      expect(described_class.grade_code_challenge(question, [ "2" ],       "highlight")).to be false
    end

    it "не засчитывает лишние выбранные строки в highlight" do
      expect(described_class.grade_code_challenge(question, [ "1,2" ], "highlight")).to be false
    end

    it "игнорирует регистр и пробелы в fill" do
      expect(described_class.grade_code_challenge(question, [ "  DISABLE_ddl_transaction!  " ], "fill")).to be true
      expect(described_class.grade_code_challenge(question, [ "что-то другое" ], "fill")).to be false
    end

    it "игнорирует пустые строки и хвостовые пробелы в fix" do
      expect(described_class.grade_code_challenge(question, [ "x = 2  \n\n" ], "fix")).to be true
      expect(described_class.grade_code_challenge(question, [ "x = 3" ],      "fix")).to be false
    end
  end

  describe ".answer_detail" do
    it "отдаёт варианты и правильные id для обычного вопроса" do
      question = {
        "id" => "q1", "text" => "Вопрос", "type" => "single", "explanation" => "потому что",
        "options" => [
          { "id" => "a", "text" => "нет", "correct" => false },
          { "id" => "b", "text" => "да",  "correct" => true }
        ]
      }

      detail = described_class.answer_detail(question, [ "b" ], true, "fill")

      expect(detail[:correct_ids]).to eq([ "b" ])
      expect(detail[:selected_options]).to eq([ "b" ])
      expect(detail[:explanation]).to eq("потому что")
      expect(detail[:options].first.keys).to contain_exactly("id", "text")
    end

    it "отдаёт дифф вместо строки в режиме fix" do
      question = {
        "id" => "c1", "text" => "Почини", "type" => "code_challenge",
        "modes" => { "fix" => { "code" => "x = 1", "answer" => "x = 2" } }
      }

      detail = described_class.answer_detail(question, [ "x = 3" ], false, "fix")

      expect(detail[:correct_answer]).to be_an(Array)
      expect(detail[:selected_answer]).to be_an(Array)
    end
  end

  describe ".diff_lines" do
    it "помечает изменённое слово как added" do
      diff = described_class.diff_lines("users.find_each", "users.in_batches")

      tokens = diff.flat_map { |line| line[:tokens].to_a }
      expect(tokens.select { |t| t[:type] == "added" }.map { |t| t[:text] }).to include("in_batches")
    end

    it "не возвращает строк, если тексты совпадают" do
      expect(described_class.diff_lines("same\nlines", "same\nlines")).to be_empty
    end

    it "помечает удалённую строку" do
      diff = described_class.diff_lines("a\nb", "a")

      expect(diff).to include(hash_including(kind: "removed", content: "b"))
    end
  end
end
