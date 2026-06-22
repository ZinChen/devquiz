require 'rails_helper'

RSpec.describe User, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:provider) }
    it { is_expected.to validate_presence_of(:uid) }
    it "validates uniqueness of uid scoped to provider" do
      create(:user, provider: "github", uid: "123")
      duplicate = build(:user, provider: "github", uid: "123")
      expect(duplicate).not_to be_valid
    end
  end

  describe "associations" do
    it { is_expected.to have_many(:test_attempts).with_foreign_key(:user_id) }
    it { is_expected.to have_many(:bookmarks).dependent(:destroy) }
    it { is_expected.to have_many(:bookmarked_questions).through(:bookmarks).source(:question) }
  end

  describe ".from_omniauth" do
    let(:auth) do
      double(
        provider: "github",
        uid: "12345",
        info: double(email: "test@example.com", name: "Test User", image: "http://avatar.url")
      )
    end

    it "creates a new user from omniauth data" do
      expect { User.from_omniauth(auth) }.to change(User, :count).by(1)
    end

    it "returns existing user on second call" do
      User.from_omniauth(auth)
      expect { User.from_omniauth(auth) }.not_to change(User, :count)
    end

    it "sets correct attributes" do
      user = User.from_omniauth(auth)
      expect(user.email).to eq("test@example.com")
      expect(user.name).to eq("Test User")
      expect(user.avatar_url).to eq("http://avatar.url")
    end
  end
end
