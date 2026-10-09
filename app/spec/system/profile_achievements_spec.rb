require "rails_helper"

RSpec.describe "Достижения в профиле", type: :system, js: true do
  let(:user) { create(:user, :with_github) }

  before do
    AchievementsCatalog.sync!
    # Первые ступени тематических лесенок — по одной плитке на тему, больше
    # страницы «Ещё» (TOPIC_ACHIEVEMENTS_PAGE_SIZE = 9).
    Achievement.where("slug LIKE 'topic\\_%\\_known'").order(:position).limit(12).each do |a|
      UserAchievement.create!(user: user, achievement: a, earned_at: Time.current)
    end

    identity = user.identities.first
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
      provider: identity.provider, uid: identity.uid,
      info: { email: user.email, name: user.name, image: user.avatar_url }
    )
    visit "/auth/github/callback"
  end

  after { OmniAuth.config.test_mode = false }

  def open_profile
    visit "/dashboard#profile"
    expect(page).to have_css(".profile__achievements-more-btn")
  end

  it "раскрытый список остаётся раскрытым после обновления страницы" do
    open_profile
    expect(page).to have_css(".profile__achievements-more-btn", text: /Ещё \d+/)

    find(".profile__achievements-more-btn").click
    expect(page).to have_css(".profile__achievements-more-btn", text: "Свернуть")

    open_profile

    expect(page).to have_css(".profile__achievements-more-btn", text: "Свернуть")
  end

  it "после «Свернуть» список остаётся свёрнутым" do
    open_profile
    find(".profile__achievements-more-btn").click
    find(".profile__achievements-more-btn", text: "Свернуть").click

    open_profile

    expect(page).to have_css(".profile__achievements-more-btn", text: /Ещё \d+/)
  end
end
