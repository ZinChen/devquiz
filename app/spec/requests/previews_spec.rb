require 'rails_helper'

RSpec.describe "Previews", type: :request do
  let(:definition) do
    {
      "title" => "Тест из файла",
      "questions" => [
        {
          "id" => "q1", "text" => "2 + 2?", "type" => "single",
          "options" => [
            { "id" => "a", "text" => "4", "correct" => true },
            { "id" => "b", "text" => "5", "correct" => false }
          ],
          "explanation" => "Арифметика"
        },
        {
          "id" => "q2", "text" => "Выбери чётные", "type" => "multiple",
          "options" => [
            { "id" => "a", "text" => "2", "correct" => true },
            { "id" => "b", "text" => "3", "correct" => false },
            { "id" => "c", "text" => "4", "correct" => true }
          ]
        }
      ]
    }
  end

  describe "POST /preview" do
    it "открывает страницу прохождения" do
      post "/preview", params: { test: definition }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Run/Preview")
    end

    it "отклоняет файл без вопросов" do
      post "/preview", params: { test: definition.merge("questions" => []) }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["errors"]).to be_present
    end
  end

  describe "GET /preview" do
    it "возвращает на список тестов с объяснением" do
      get "/preview"

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to match(/перетаскиванием/)
    end
  end

  describe "POST /preview/grade" do
    def grade(answers, extra = {})
      post "/preview/grade", params: { test: definition, answers: answers }.merge(extra)
      response.parsed_body
    end

    it "считает результат" do
      body = grade({ "q1" => [ "a" ], "q2" => [ "a", "c" ] })

      expect(body["attempt"]["score"]).to eq(100.0)
      expect(body["attempt"]["correct_count"]).to eq(2)
      expect(body["attempt"]["total_questions"]).to eq(2)
    end

    it "ничего не пишет в базу" do
      counts = -> { [ TestAttempt.count, TestAttemptAnswer.count, TestMetadatum.count, Question.count ] }

      expect { grade({ "q1" => [ "a" ], "q2" => [ "a", "c" ] }) }.not_to change(&counts)
    end

    it "отмечает неверные ответы" do
      body = grade({ "q1" => [ "b" ], "q2" => [ "a" ] })

      expect(body["attempt"]["score"]).to eq(0.0)
      expect(body["answers_detail"].map { |d| d["correct"] }).to all(be false)
    end

    it "возвращает разбор с вариантами и пояснением" do
      detail = grade({ "q1" => [ "a" ] })["answers_detail"].first

      expect(detail["question_text"]).to eq("2 + 2?")
      expect(detail["correct_ids"]).to eq([ "a" ])
      expect(detail["selected_options"]).to eq([ "a" ])
      expect(detail["explanation"]).to eq("Арифметика")
    end

    it "считает неотвеченные вопросы в знаменателе" do
      body = grade({ "q1" => [ "a" ] })

      expect(body["attempt"]["total_questions"]).to eq(2)
      expect(body["attempt"]["score"]).to eq(50.0)
    end

    it "не проставляет режим кода тесту без code_challenge" do
      expect(grade({ "q1" => [ "a" ] })["attempt"]["challenge_mode"]).to be_nil
    end

    it "игнорирует ответы на несуществующие вопросы" do
      body = grade({ "q1" => [ "a" ], "нет-такого" => [ "z" ] })

      expect(body["answers_detail"].size).to eq(1)
    end

    it "отклоняет некорректное определение теста" do
      post "/preview/grade", params: { test: { "title" => "Без вопросов" }, answers: {} }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "POST /preview/grade с code_challenge" do
    let(:code_definition) do
      {
        "title" => "Код",
        "questions" => [ {
          "id" => "c1", "text" => "Почини", "type" => "code_challenge",
          "modes" => {
            "highlight" => { "code" => "a\nb\nc", "correct_lines" => [ "after:1" ], "insert_text" => "  x" },
            "fill"      => { "code" => "___", "answer" => [ "disable_ddl_transaction!" ] }
          }
        } ]
      }
    end

    def grade_code(answers, mode)
      post "/preview/grade", params: { test: code_definition, answers: answers, challenge_mode: mode }
      response.parsed_body
    end

    it "принимает эквивалентную форму строки в highlight" do
      expect(grade_code({ "c1" => [ "after:1" ] }, "highlight")["attempt"]["correct_count"]).to eq(1)
      expect(grade_code({ "c1" => [ "1" ] },       "highlight")["attempt"]["correct_count"]).to eq(1)
      expect(grade_code({ "c1" => [ "3" ] },       "highlight")["attempt"]["correct_count"]).to eq(0)
    end

    it "сверяет ответ без учёта регистра в fill" do
      expect(grade_code({ "c1" => [ "DISABLE_ddl_transaction!" ] }, "fill")["attempt"]["correct_count"]).to eq(1)
    end

    it "возвращает код и режим в разборе" do
      detail = grade_code({ "c1" => [ "after:1" ] }, "highlight")["answers_detail"].first

      expect(detail["challenge_mode"]).to eq("highlight")
      expect(detail["code"]).to eq("a\nb\nc")
      expect(detail["insert_text"]).to eq("  x")
    end
  end
end
