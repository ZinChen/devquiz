require "rails_helper"

RSpec.describe "Pages", type: :request do
  let(:test_meta) { create(:test_metadatum) }
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

  describe "GET /" do
    it "returns 200" do
      get root_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /login" do
    it "returns 200" do
      get login_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /stats" do
    it "returns 200" do
      get stats_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /tests/:slug" do
    it "returns 200 for existing test" do
      get test_path(test_meta.slug)
      expect(response).to have_http_status(:ok)
    end

    it "returns 404 for unknown slug" do
      get test_path("nonexistent")
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /tests/:slug/run/new" do
    it "returns 200" do
      get new_test_run_path(test_meta.slug)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /dashboard" do
    it "redirects to login when not authenticated" do
      get dashboard_path
      expect(response).to redirect_to(login_path)
    end

    it "returns 200 when authenticated" do
      sign_in(user)
      get dashboard_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "DELETE /logout" do
    it "redirects to root" do
      sign_in(user)
      delete logout_path
      expect(response).to redirect_to(root_path)
    end
  end

  describe "signing in with two providers sharing one email" do
    def oauth_login(provider, uid, email)
      OmniAuth.config.test_mode = true
      OmniAuth.config.mock_auth[provider.to_sym] = OmniAuth::AuthHash.new(
        provider: provider,
        uid: uid,
        info: { email: email, name: "Same Person", image: "http://img" },
        extra: { raw_info: { email_verified: "true" } }
      )
      get "/auth/#{provider}/callback"
    end

    it "lands both logins on the same account" do
      oauth_login("github", "gh-100", "same@example.com")
      github_user_id = session[:user_id]
      expect(github_user_id).to be_present

      delete logout_path

      oauth_login("google_oauth2", "gg-100", "same@example.com")

      expect(session[:user_id]).to eq(github_user_id)
      expect(User.count).to eq(1)
      expect(User.first.connected_providers).to contain_exactly("github", "google_oauth2")
    end
  end
end
