require "rails_helper"

RSpec.describe "Режим прохождения на странице результата", type: :request do
  def complete_and_open(slug)
    post "/tests/#{slug}/run", params: {
      answers: { "q1" => [ "b" ] }, started_at: 1.minute.ago.iso8601, time_spent: 60
    }
    get response.location, headers: { "X-Inertia" => "true" }
    response.parsed_body["props"]
  end

  # Режим пишется в попытку всегда, поэтому страница должна уметь понять,
  # что для этого теста он бессмыслен: иначе показывался бейдж «Highlight»
  # и предложение пройти в режиме Fix на тесте без единого блока кода.
  it "сообщает, что в тесте нет заданий с кодом" do
    create(:test_metadatum, slug: "ror-basics", questions_count: 20, has_code_challenge: false)

    props = complete_and_open("ror-basics")

    expect(props["test"]["has_code_challenge"]).to be false
  end

  it "сообщает о заданиях с кодом, когда они есть" do
    create(:test_metadatum, slug: "ror-migrations-large-tables", questions_count: 12, has_code_challenge: true)

    props = complete_and_open("ror-migrations-large-tables")

    expect(props["test"]["has_code_challenge"]).to be true
  end
end
