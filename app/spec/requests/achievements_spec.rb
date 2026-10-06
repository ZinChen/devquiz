require "rails_helper"

RSpec.describe "Достижения", type: :request do
  let!(:meta) { create(:test_metadatum, slug: "ror-basics", questions_count: 2, difficulty: "basic") }
  let(:user) { create(:user, :with_github) }

  before { AchievementsCatalog.sync! }

  def sign_in(u)
    identity = u.identities.first
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
      provider: identity.provider, uid: identity.uid,
      info: { email: u.email, name: u.name }
    )
    get "/auth/github/callback"
  end

  after { OmniAuth.config.test_mode = false }

  # q1/q2 существуют в tests/ror-basics.yml — их верные ответы берутся из файла.
  def complete_test(answers = { "q1" => [ "wrong" ], "q2" => [ "wrong" ] })
    post "/tests/#{meta.slug}/run", params: {
      answers:    answers,
      started_at: 1.minute.ago.iso8601,
      time_spent: 60
    }
    get response.location, headers: { "X-Inertia" => "true" }
  end

  describe "после прохождения теста" do
    before { sign_in(user) }

    it "показывает выданные ачивки на странице результата" do
      complete_test

      slugs = response.parsed_body["props"]["new_achievements"].map { |a| a["slug"] }
      expect(slugs).to include("first_test")
    end

    it "отдаёт название, описание и иконку для блока" do
      complete_test

      achievement = response.parsed_body["props"]["new_achievements"].first
      expect(achievement).to include("title", "description", "icon")
    end

    it "не показывает ачивку повторно на следующем тесте" do
      complete_test
      complete_test

      slugs = response.parsed_body["props"]["new_achievements"].map { |a| a["slug"] }
      expect(slugs).not_to include("first_test")
    end

    it "не предлагает регистрацию авторизованному" do
      complete_test

      expect(response.parsed_body["props"]["guest_prompt"]).to be(false)
    end
  end

  describe "гость" do
    it "не получает ачивок" do
      complete_test

      expect(response.parsed_body["props"]["new_achievements"]).to eq([])
      expect(UserAchievement.count).to eq(0)
    end

    it "видит приглашение зарегистрироваться после первого теста" do
      complete_test

      expect(response.parsed_body["props"]["guest_prompt"]).to be(true)
    end

    it "не видит приглашение повторно" do
      complete_test
      complete_test

      expect(response.parsed_body["props"]["guest_prompt"]).to be(false)
    end
  end

  describe "при логине" do
    it "выдаёт ачивки за перенесённую гостевую историю" do
      complete_test
      expect(UserAchievement.count).to eq(0)

      sign_in(user)

      expect(user.achievements.pluck(:slug)).to include("first_test")
    end

    it "сообщает о начислении в приветствии" do
      complete_test
      sign_in(user)

      expect(flash[:notice]).to include("Начислены достижения")
    end

    it "не поминает достижения, когда начислять нечего" do
      sign_in(user)

      expect(flash[:notice]).not_to include("достижения")
    end
  end

  describe "в кабинете" do
    before { sign_in(user) }

    it "отдаёт сводку с плитками и прогрессом" do
      complete_test
      get "/dashboard", headers: { "X-Inertia" => "true" }

      achievements = response.parsed_body["props"]["achievements"]
      expect(achievements["earned_count"]).to be_positive
      # Счёт по плиткам, а не по ступеням: под шапкой лежит ровно столько
      # карточек, сколько названо в знаменателе.
      expect(achievements["total_count"]).to eq(achievements["items"].size)
      expect(achievements["items"]).to be_present
    end
  end

  describe "избранное" do
    before { sign_in(user) }

    it "возвращает выданную ачивку в ответе, чтобы клиент показал тост" do
      9.times { create(:bookmark, user: user, question: create(:question)) }
      question = create(:question)

      post "/bookmarks", params: { question_id: question.id }

      slugs = response.parsed_body["new_achievements"].map { |a| a["slug"] }
      expect(slugs).to include("hoarder")
    end

    it "ничего не возвращает, когда порог не достигнут" do
      post "/bookmarks", params: { question_id: create(:question).id }

      expect(response.parsed_body["new_achievements"]).to eq([])
    end
  end
end
