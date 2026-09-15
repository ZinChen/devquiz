require "rails_helper"

RSpec.describe "Слабые темы в кабинете", type: :request do
  let(:user) { create(:user, :with_github) }
  let!(:meta)  { create(:test_metadatum, slug: "ror-basics", questions_count: 2, tags: "ruby,rails") }
  let!(:other) { create(:test_metadatum, slug: "ror-interview", tags: "ruby,rails") }

  def sign_in(u)
    identity = u.identities.first
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
      provider: identity.provider, uid: identity.uid,
      info: { email: u.email, name: u.name, image: u.avatar_url }
    )
    get "/auth/github/callback"
  end

  after { OmniAuth.config.test_mode = false }

  def dashboard_props
    get "/dashboard", headers: { "X-Inertia" => "true" }
    response.parsed_body["props"]
  end

  def complete_test(answers)
    post "/tests/#{meta.slug}/run", params: {
      answers: answers, started_at: 1.minute.ago.iso8601, time_spent: 60
    }
  end

  before { sign_in(user) }

  it "показывает слабые темы по всей истории" do
    complete_test({ "q1" => [ "wrong" ], "q2" => [ "wrong" ], "q5" => [ "wrong" ] })

    topics = dashboard_props["weak_topics"]
    expect(topics.map { |t| t["slug"] }).to eq(%w[mvc controllers])
    expect(topics.first["wrong_count"]).to eq(2)
    expect(topics.first["level"]).to eq("medium")
  end

  it "не показывает темы, если ошибок не было" do
    complete_test({ "q1" => [ "b" ], "q2" => [ "b" ] })

    expect(dashboard_props["weak_topics"]).to be_empty
  end

  it "показывает, из каких тестов набралась тема" do
    complete_test({ "q1" => [ "wrong" ], "q2" => [ "wrong" ] })

    sources = dashboard_props["weak_topics"].first["sources"]
    expect(sources.first["slug"]).to eq("ror-basics")
    expect(sources.first["wrong_count"]).to eq(2)
  end

  # Ищем через TopicIndex: mvc в tags тестов не встречается, поиск по тегам
  # такой тест не нашёл бы.
  it "рекомендует тесты с вопросами по слабой теме, непройденные первыми" do
    complete_test({ "q1" => [ "wrong" ], "q2" => [ "wrong" ] })

    recommended = dashboard_props["recommended_tests"]
    expect(recommended.map { |t| t["slug"] }).to include("ror-interview")
    expect(recommended.first["completed"]).to be false
    expect(recommended.first["topics"]).to include("MVC & Request lifecycle")
  end

  it "не рекомендует ничего без истории" do
    expect(dashboard_props["recommended_tests"]).to be_empty
  end
end
