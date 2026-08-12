require "rails_helper"

RSpec.describe "Предпочтения по тегам", type: :request do
  let(:user) { create(:user, :with_github) }

  def sign_in(user)
    identity = user.identities.first
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
      provider: identity.provider,
      uid: identity.uid,
      info: { email: user.email, name: user.name, image: user.avatar_url }
    )
    get "/auth/github/callback"
  end

  after { OmniAuth.config.test_mode = false }

  describe "PATCH /preferences/tags" do
    it "сохраняет выбор авторизованного пользователя" do
      sign_in(user)

      patch preferences_tags_path, params: { tags: [ "ruby", "devops" ] }

      expect(user.reload.preferred_tags).to eq([ "ruby", "devops" ])
    end

    it "отбрасывает неизвестные и служебные теги" do
      sign_in(user)

      patch preferences_tags_path, params: { tags: [ "ruby", "hh", "выдумка" ] }

      expect(user.reload.preferred_tags).to eq([ "ruby" ])
    end

    it "отличает пустой выбор от отсутствия выбора" do
      sign_in(user)
      expect(user.reload.preferred_tags).to be_nil

      patch preferences_tags_path, params: { tags: [] }

      expect(user.reload.preferred_tags).to eq([])
    end

    it "принимает выбор гостя без авторизации" do
      patch preferences_tags_path, params: { tags: [ "ruby" ] }

      expect(response).to have_http_status(:redirect)
      # Гостевой выбор оседает в куке и подхватывается главной.
      get root_path
      expect(response.body).to include("ruby")
    end
  end

  describe "GET /settings/tags" do
    it "открывается авторизованному пользователю с его выбором" do
      sign_in(user)
      patch preferences_tags_path, params: { tags: [ "ruby" ] }

      get settings_tags_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("preferred_tags&quot;:[&quot;ruby&quot;]")
    end

    it "открывается гостю и не требует входа" do
      get settings_tags_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Settings/Tags")
    end

    it "показывает гостю выбор из куки" do
      patch preferences_tags_path, params: { tags: [ "devops" ] }

      get settings_tags_path

      expect(response.body).to include("preferred_tags&quot;:[&quot;devops&quot;]")
    end

    it "отдаёт описания категорий" do
      get settings_tags_path

      expect(response.body).to include("description")
    end
  end

  describe "GET / — признак онбординга" do
    it "показывает экран выбора новому пользователю" do
      sign_in(user)

      get root_path

      expect(response.body).to include("show_tag_onboarding&quot;:true")
    end

    it "не показывает экран повторно после выбора" do
      sign_in(user)
      patch preferences_tags_path, params: { tags: [ "ruby" ] }

      get root_path

      expect(response.body).to include("show_tag_onboarding&quot;:false")
    end

    it "не показывает экран повторно после пропуска" do
      sign_in(user)
      patch preferences_tags_path, params: { tags: [] }

      get root_path

      expect(response.body).to include("show_tag_onboarding&quot;:false")
    end

    it "показывает экран гостю, зашедшему впервые" do
      get root_path

      expect(response.body).to include("show_tag_onboarding&quot;:true")
    end

    it "не показывает экран гостю, который уже выбрал темы" do
      patch preferences_tags_path, params: { tags: [ "ruby" ] }

      get root_path

      expect(response.body).to include("show_tag_onboarding&quot;:false")
    end

    it "не показывает экран сразу после выхода из аккаунта" do
      sign_in(user)
      patch preferences_tags_path, params: { tags: [ "ruby" ] }

      delete logout_path
      get root_path

      expect(response.body).to include("show_tag_onboarding&quot;:false")
      expect(response.body).to include("preferred_tags&quot;:[&quot;ruby&quot;]")
    end
  end
end
