require "rails_helper"

RSpec.describe "Порядок вопросов в разборе попытки", type: :request do
  let!(:meta) { create(:test_metadatum, slug: "ror-basics", questions_count: 5, tags: "ruby,rails,backend") }

  def complete_test(answers)
    post "/tests/#{meta.slug}/run", params: {
      answers:    answers,
      started_at: 1.minute.ago.iso8601,
      time_spent: 60
    }
    get response.location, headers: { "X-Inertia" => "true" }
  end

  # Номера «Вопрос N» на странице — позиция в списке разбора, поэтому список
  # должен идти в порядке теста, как бы строки ни лежали в таблице ответов.
  it "отдаёт ответы в порядке вопросов теста, а не в порядке строк в БД" do
    complete_test({ "q3" => [ "b" ], "q1" => [ "b" ], "q2" => [ "b" ] })

    ids = response.parsed_body["props"]["answers_detail"].map { |a| a["question_id"] }
    expect(ids).to eq(%w[q1 q2 q3])
  end
end
