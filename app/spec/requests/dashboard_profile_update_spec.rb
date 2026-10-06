require "rails_helper"

RSpec.describe "Обновление профиля в кабинете", type: :request do
  def sign_in_as(user)
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
      provider: "github",
      uid: "uid-#{user.id}",
      info: { email: user.email, name: "Real Name", image: "http://real.avatar" }
    )
    get "/auth/github/callback"
  end

  after { OmniAuth.config.test_mode = false }

  let(:user) { create(:user, avatar_url: nil) }

  before { sign_in_as(user) }

  it "сохраняет обычную http(s)-ссылку на аватар" do
    patch "/dashboard", params: { name: user.name, avatar_url: "https://example.com/me.png" }

    expect(user.reload.avatar_url).to eq("https://example.com/me.png")
  end

  it "отклоняет javascript: URI и не меняет сохранённое значение" do
    patch "/dashboard", params: { name: user.name, avatar_url: "javascript:alert(1)" }

    expect(user.reload.avatar_url).to be_nil
  end

  it "отклоняет data: URI" do
    patch "/dashboard", params: { name: user.name, avatar_url: "data:text/html,<script>alert(1)</script>" }

    expect(user.reload.avatar_url).to be_nil
  end

  it "принимает пустую ссылку как сброс к сгенерированному аватару" do
    user.update!(avatar_url: "https://example.com/old.png")

    patch "/dashboard", params: { name: user.name, avatar_url: "" }

    expect(user.reload.avatar_url).to be_blank
  end
end
