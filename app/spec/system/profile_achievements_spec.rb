require "rails_helper"

RSpec.describe "Достижения в профиле", type: :system, js: true do
  let(:user) { create(:user, :with_github) }

  before do
    # Каталог тематических ачивок строится из TopicIndex и кэшируется на процесс.
    # Системные спеки, подменяющие TestSource на временный каталог без тем,
    # оставляли в кэше пустой индекс — и здесь тематических ачивок (а с ними
    # кнопки «Ещё») не было, но только в полном прогоне, зависимо от порядка.
    TopicIndex.reload!
    AchievementsCatalog.reload!
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

  it "в полоске последних достижений вместо прогресса показана дата" do
    visit "/dashboard"
    expect(page).to have_css(".achievements--compact .achievement", minimum: 1)

    # У первых ступеней тематических лесенок есть следующая ступень, то есть
    # раньше здесь рисовалась полоска прогресса.
    expect(page).to have_no_css(".achievements--compact .achievement__progress")
    expect(page).to have_css(".achievements--compact .achievement__date", minimum: 1)
  end
end
