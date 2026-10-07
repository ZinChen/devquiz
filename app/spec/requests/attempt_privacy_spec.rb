require "rails_helper"

RSpec.describe "Приватность данных о прохождениях", type: :request do
  let!(:meta)  { create(:test_metadatum, slug: "ror-basics", questions_count: 1, attempts_count: 7, best_score: 100, best_attempt_id: 999) }
  let(:alice)  { create(:user, :with_github) }
  let(:bob)    { create(:user, :with_github) }

  def sign_in(user)
    identity = user.identities.first
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
      provider: identity.provider, uid: identity.uid,
      info: { email: user.email, name: user.name, image: user.avatar_url }
    )
    get "/auth/github/callback"
  end

  after { OmniAuth.config.test_mode = false }

  def attempt_for(user, score: 80, **attrs)
    TestAttempt.create!(
      user_id: user&.id, test_slug: meta.slug, total_questions: 1, score: score,
      correct_count: 1, completed_at: Time.current, **attrs
    )
  end

  def inertia_props
    page = Nokogiri::HTML(response.body).at_css("[data-page]")&.[]("data-page")
    JSON.parse(page).fetch("props")
  end

  describe "карточки на главной" do
    it "гость не видит ни чужих попыток, ни чужого лучшего результата" do
      get "/"

      card = inertia_props.fetch("tests").find { |t| t["slug"] == "ror-basics" }
      expect(card).to include("attempts_count" => 0, "best_score" => nil, "best_attempt_id" => nil)
    end

    it "пользователь видит только свои цифры" do
      sign_in(alice)
      mine = attempt_for(alice, score: 60)
      attempt_for(alice, score: 90)
      attempt_for(bob, score: 100)

      get "/"

      card = inertia_props.fetch("tests").find { |t| t["slug"] == "ror-basics" }
      expect(card).to include("attempts_count" => 2, "best_score" => 90.0)
      expect(card["best_attempt_id"]).not_to eq(mine.id)
    end

    it "разбор ошибок в личную статистику не входит" do
      sign_in(alice)
      attempt_for(alice, score: 100, weak_only: true)

      get "/"

      card = inertia_props.fetch("tests").find { |t| t["slug"] == "ror-basics" }
      expect(card["attempts_count"]).to eq(0)
    end
  end

  describe "страница теста" do
    it "не отдаёт гостю общие счётчики" do
      get "/tests/ror-basics"

      expect(inertia_props.fetch("test")).to include("attempts_count" => 0, "best_score" => nil)
      expect(inertia_props.fetch("test")).not_to have_key("pass_rate")
    end
  end

  describe "страница результата" do
    it "гость не открывает чужую попытку" do
      other = attempt_for(bob)

      get "/tests/ror-basics/runs/#{other.id}"

      expect(response).to have_http_status(:not_found)
    end

    it "пользователь не открывает попытку другого пользователя" do
      other = attempt_for(bob)
      sign_in(alice)

      get "/tests/ror-basics/runs/#{other.id}"

      expect(response).to have_http_status(:not_found)
    end

    it "пользователь открывает свою попытку" do
      sign_in(alice)
      mine = attempt_for(alice)

      get "/tests/ror-basics/runs/#{mine.id}"

      expect(response).to have_http_status(:ok)
    end

    it "гость открывает свою только что пройденную попытку" do
      post "/tests/ror-basics/run", params: {
        answers: { "q1" => [ "a" ] }, started_at: 1.minute.ago.iso8601, time_spent: 10
      }

      follow_redirect!

      expect(response).to have_http_status(:ok)
    end

    it "гость не открывает гостевую попытку с другим токеном" do
      other = attempt_for(nil, guest_token: "чужой-токен")

      get "/tests/ror-basics/runs/#{other.id}"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "история попыток по тесту" do
    it "гостя отправляет на вход" do
      get "/tests/ror-basics/attempts"

      expect(response).to redirect_to("/login")
    end

    it "показывает только попытки самого пользователя" do
      sign_in(alice)
      mine = attempt_for(alice)
      attempt_for(bob)

      get "/tests/ror-basics/attempts"

      ids = inertia_props.fetch("attempts").map { |a| a["id"] }
      expect(ids).to eq([ mine.id ])
    end
  end
end
