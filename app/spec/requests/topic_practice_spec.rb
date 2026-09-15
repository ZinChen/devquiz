require "rails_helper"

RSpec.describe "Тренировка по теме", type: :request do
  let(:user) { create(:user, :with_github) }
  let!(:basics)    { create(:test_metadatum, slug: "ror-basics", questions_count: 20, tags: "ruby,rails") }
  let!(:interview) { create(:test_metadatum, slug: "ror-interview", questions_count: 20, tags: "ruby,rails") }

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

  # q1/q2 в ror-basics.yml помечены topics: [mvc].
  def fail_mvc_questions
    post "/tests/ror-basics/run", params: {
      answers: { "q1" => [ "wrong" ], "q2" => [ "wrong" ] },
      started_at: 1.minute.ago.iso8601, time_spent: 60
    }
  end

  def open_practice(topic = "mvc")
    get "/practice/topic/#{topic}", headers: { "X-Inertia" => "true" }
  end

  before { sign_in(user) }

  it "собирает вопросы, где пользователь ошибался" do
    fail_mvc_questions
    open_practice

    questions = response.parsed_body["props"]["questions"]
    expect(questions.map { |q| q["id"] }).to match_array(%w[q1 q2])
    expect(questions.first["test_title"]).to eq(basics.title)
  end

  it "уводит в кабинет, если по теме нечего повторять" do
    open_practice

    expect(response).to redirect_to(dashboard_path)
  end

  it "уводит в кабинет для неизвестной темы" do
    fail_mvc_questions
    open_practice("no-such-topic")

    expect(response).to redirect_to(dashboard_path)
  end

  it "не отдаёт чужие слабые вопросы" do
    fail_mvc_questions

    sign_in(create(:user, :with_github))
    open_practice

    expect(response).to redirect_to(dashboard_path)
  end

  describe "проверка ответов" do
    def grade(answers)
      post "/practice/topic/mvc/grade",
           params: { answers: answers }.to_json,
           headers: { "CONTENT_TYPE" => "application/json" }
      response.parsed_body
    end

    it "считает верные ответы и возвращает разбор" do
      fail_mvc_questions

      body = grade({ "q1" => { "test_slug" => "ror-basics", "selected" => [ "b" ] } })

      expect(body["correct_count"]).to eq(1)
      expect(body["total"]).to eq(1)
      expect(body["details"].first["test_slug"]).to eq("ror-basics")
    end

    # Без записи в историю тема никогда бы не закрылась.
    it "записывает ответы, чтобы вопрос ушёл из слабых" do
      fail_mvc_questions

      2.times do
        grade({
          "q1" => { "test_slug" => "ror-basics", "selected" => [ "b" ] },
          "q2" => { "test_slug" => "ror-basics", "selected" => [ "b" ] }
        })
      end

      expect(WeakQuestions.for(user: user).entries).to be_empty
    end

    it "не влияет на статистику теста" do
      fail_mvc_questions
      stats = basics.reload.slice(:attempts_count, :avg_score, :best_score)

      grade({ "q1" => { "test_slug" => "ror-basics", "selected" => [ "b" ] } })

      expect(basics.reload.slice(:attempts_count, :avg_score, :best_score)).to eq(stats)
    end
  end
end
