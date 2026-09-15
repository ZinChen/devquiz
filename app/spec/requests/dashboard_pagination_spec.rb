require "rails_helper"

RSpec.describe "Пагинация в кабинете", type: :request do
  # Через константу, чтобы тест переживал смену размера страницы.
  let(:page_size) { DashboardController::PAGE_SIZE }
  let(:user) { create(:user, :with_github) }
  let!(:meta) { create(:test_metadatum, slug: "ror-basics", questions_count: 20) }

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

  def create_attempts(count)
    count.times do |i|
      TestAttempt.create!(
        user_id: user.id, test_slug: "ror-basics", total_questions: 20,
        correct_count: 10, score: 50, started_at: 1.hour.ago,
        completed_at: i.minutes.ago
      )
    end
  end

  def dashboard_props
    get "/dashboard", headers: { "X-Inertia" => "true" }
    response.parsed_body["props"]
  end

  before { sign_in(user) }

  describe "история прохождений" do
    it "отдаёт первую страницу и признак продолжения" do
      create_attempts(page_size + 3)

      props = dashboard_props
      expect(props["attempts"].size).to eq(page_size)
      expect(props["has_more_attempts"]).to be true
    end

    it "не обещает продолжения, когда всё поместилось" do
      create_attempts(page_size - 1)

      props = dashboard_props
      expect(props["attempts"].size).to eq(page_size - 1)
      expect(props["has_more_attempts"]).to be false
    end

    it "догружает следующую страницу" do
      create_attempts(page_size + 3)

      get "/dashboard/attempts", params: { offset: page_size }

      body = response.parsed_body
      expect(body["attempts"].size).to eq(3)
      expect(body["has_more"]).to be false
    end

    it "не повторяет уже показанные попытки" do
      create_attempts(page_size + 3)

      first_page = dashboard_props["attempts"].map { |a| a["id"] }
      get "/dashboard/attempts", params: { offset: page_size }
      second_page = response.parsed_body["attempts"].map { |a| a["id"] }

      expect(first_page & second_page).to be_empty
    end

    # Сводка считается по всей истории, а не по показанной странице.
    it "не режет статистику по размеру страницы" do
      create_attempts(page_size + 3)

      expect(dashboard_props["stats"]["total_attempts"]).to eq(page_size + 3)
    end
  end

  describe "избранные вопросы" do
    def create_bookmarks(count)
      count.times do |i|
        question = create(:question, test_slug: "ror-basics", question_id: "q#{i}")
        Bookmark.create!(user: user, question: question, created_at: i.minutes.ago)
      end
    end

    it "отдаёт первую страницу и признак продолжения" do
      create_bookmarks(page_size + 3)

      props = dashboard_props
      expect(props["bookmarks"].size).to eq(page_size)
      expect(props["has_more_bookmarks"]).to be true
    end

    it "догружает следующую страницу" do
      create_bookmarks(page_size + 3)

      get "/dashboard/bookmarks", params: { offset: page_size }

      body = response.parsed_body
      expect(body["bookmarks"].size).to eq(3)
      expect(body["has_more"]).to be false
    end
  end

  it "требует авторизации" do
    delete "/logout"

    get "/dashboard/attempts"

    expect(response).to redirect_to(login_path)
  end
end
