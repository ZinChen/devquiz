require "rails_helper"

RSpec.describe "Гостевая личность", type: :request do
  let!(:meta) { create(:test_metadatum, slug: "ror-basics", questions_count: 1) }

  def sign_in_as_new_user(email:)
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
      provider: "github",
      uid: "new-#{email}",
      info: { email: email, name: "Real Name", image: "http://real.avatar" }
    )
    get "/auth/github/callback"
  end

  after { OmniAuth.config.test_mode = false }

  def complete_test_as_guest
    post "/tests/#{meta.slug}/run", params: {
      answers:    { "q1" => [ "a" ] },
      started_at: 1.minute.ago.iso8601,
      time_spent: 60
    }
  end

  it "присваивает гостю имя и аватар при первом реальном действии" do
    complete_test_as_guest

    get "/dashboard" # любая страница — читаем гостевую identity через inertia_share
    get "/", headers: { "X-Inertia" => "true" }

    identity = response.parsed_body["props"]["guest_identity"]
    expect(identity).to be_present
    expect(identity["name"]).to be_present
    expect(identity["avatar_seed"]).to be_present
  end

  it "не ставит гостевую куку простому визиту без действий" do
    get "/", headers: { "X-Inertia" => "true" }

    expect(response.parsed_body["props"]["guest_identity"]).to be_nil
  end

  it "новый аккаунт наследует имя и аватар, которые уже были у гостя" do
    complete_test_as_guest

    get "/", headers: { "X-Inertia" => "true" }
    guest_identity = response.parsed_body["props"]["guest_identity"]

    sign_in_as_new_user(email: "brand-new@example.com")

    user = User.find_by_email("brand-new@example.com")
    expect(user.name).to eq(guest_identity["name"])
    expect(user.avatar_seed).to eq(guest_identity["avatar_seed"])
    # Настоящее имя из OAuth не подставляется автоматически — только по кнопке в профиле.
    expect(user.name).not_to eq("Real Name")
  end

  it "существующий аккаунт не теряет своё имя из-за гостевой куки" do
    existing = create(:user, :with_google, name: "Уже Есть Имя")
    complete_test_as_guest

    OmniAuth.config.test_mode = true
    identity = existing.identities.first
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: identity.provider, uid: identity.uid,
      info: { email: existing.email, name: existing.name, image: existing.avatar_url },
      extra: { raw_info: { email_verified: "true" } }
    )
    get "/auth/google_oauth2/callback"

    expect(existing.reload.name).to eq("Уже Есть Имя")
  end

  it "удаляет гостевую куку после переноса в аккаунт" do
    complete_test_as_guest
    sign_in_as_new_user(email: "cleanup@example.com")

    get "/", headers: { "X-Inertia" => "true" }
    expect(response.parsed_body["props"]["guest_identity"]).to be_nil
  end
end
