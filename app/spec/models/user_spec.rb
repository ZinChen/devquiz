require 'rails_helper'

RSpec.describe User, type: :model do
  def omniauth(provider:, uid:, email:, name: "Test User", image: "http://avatar.url", verified: true)
    extra = if provider == "google_oauth2"
      double(raw_info: double(email_verified: verified.to_s))
    end

    double(
      provider: provider,
      uid: uid,
      info: double(email: email, name: name, image: image),
      extra: extra
    )
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:email) }
  end

  describe "associations" do
    it { is_expected.to have_many(:identities).dependent(:destroy) }
    it { is_expected.to have_many(:test_attempts).with_foreign_key(:user_id) }
    it { is_expected.to have_many(:bookmarks).dependent(:destroy) }
    it { is_expected.to have_many(:bookmarked_questions).through(:bookmarks).source(:question) }
  end

  describe ".from_omniauth" do
    let(:github_auth) { omniauth(provider: "github", uid: "gh-1", email: "test@example.com") }

    it "creates a new user with an identity" do
      expect { User.from_omniauth(github_auth) }.to change(User, :count).by(1)
      user = User.find_by_email("test@example.com")
      expect(user.identities.pluck(:provider, :uid)).to eq([ [ "github", "gh-1" ] ])
    end

    it "sets profile attributes" do
      user = User.from_omniauth(github_auth)
      expect(user.email).to eq("test@example.com")
      expect(user.name).to eq("Test User")
      expect(user.avatar_url).to eq("http://avatar.url")
    end

    it "returns the same user on repeat login" do
      first = User.from_omniauth(github_auth)
      expect { @second = User.from_omniauth(github_auth) }.not_to change(User, :count)
      expect(@second.id).to eq(first.id)
    end

    it "normalises email to lowercase" do
      user = User.from_omniauth(omniauth(provider: "github", uid: "gh-9", email: "MiXeD@Example.COM"))
      expect(user.email).to eq("mixed@example.com")
    end

    it "raises when the provider returns no email" do
      auth = omniauth(provider: "github", uid: "gh-2", email: nil)
      expect { User.from_omniauth(auth) }.to raise_error(User::OmniauthError, /email/i)
    end

    context "when the same email arrives from a second provider" do
      let(:google_auth) { omniauth(provider: "google_oauth2", uid: "gg-1", email: "test@example.com") }

      it "links to the existing account instead of creating a new one" do
        existing = User.from_omniauth(github_auth)

        expect { @linked = User.from_omniauth(google_auth) }.not_to change(User, :count)
        expect(@linked.id).to eq(existing.id)
        expect(@linked.connected_providers).to contain_exactly("github", "google_oauth2")
      end

      it "matches regardless of email casing" do
        existing = User.from_omniauth(github_auth)
        linked = User.from_omniauth(omniauth(provider: "google_oauth2", uid: "gg-2", email: "TEST@Example.com"))
        expect(linked.id).to eq(existing.id)
      end

      it "keeps both logins pointing at the merged account" do
        User.from_omniauth(github_auth)
        User.from_omniauth(google_auth)

        expect(User.from_omniauth(github_auth).id).to eq(User.from_omniauth(google_auth).id)
        expect(User.count).to eq(1)
      end

      it "refuses to link when Google has not verified the email" do
        User.from_omniauth(github_auth)
        unverified = omniauth(provider: "google_oauth2", uid: "gg-3", email: "test@example.com", verified: false)

        expect { User.from_omniauth(unverified) }.to raise_error(User::OmniauthError, /не подтверждён/i)
        expect(User.count).to eq(1)
      end
    end

    it "keeps separate accounts for different emails" do
      User.from_omniauth(github_auth)
      User.from_omniauth(omniauth(provider: "google_oauth2", uid: "gg-4", email: "other@example.com"))
      expect(User.count).to eq(2)
    end

    it "fills in blank profile fields on a later login" do
      user = User.from_omniauth(omniauth(provider: "github", uid: "gh-3", email: "blank@example.com", name: nil, image: nil))
      expect(user.name).to be_blank

      User.from_omniauth(omniauth(provider: "google_oauth2", uid: "gg-5", email: "blank@example.com", name: "Real Name", image: "http://img"))
      expect(user.reload.name).to eq("Real Name")
      expect(user.avatar_url).to eq("http://img")
    end

    it "does not overwrite an existing name with provider data" do
      User.from_omniauth(github_auth)
      user = User.from_omniauth(omniauth(provider: "google_oauth2", uid: "gg-6", email: "test@example.com", name: "Other Name"))
      expect(user.name).to eq("Test User")
    end
  end

  describe "#connected_providers" do
    it "lists every linked provider" do
      user = create(:user, :with_github, :with_google)
      expect(user.connected_providers).to contain_exactly("github", "google_oauth2")
    end
  end
end
