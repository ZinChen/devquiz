require "rails_helper"

RSpec.describe "Карточка участника активности", type: :system, js: true do
  let!(:meta)   { create(:test_metadatum, slug: "live-test", title: "Живой тест") }
  let!(:other)  { create(:test_metadatum, slug: "other-test", title: "Другой тест") }
  let(:member)  { create(:user, name: "Бодрый Суслик") }

  before do
    AchievementsCatalog.sync!
    %w[first_test perfect_score].each do |slug|
      UserAchievement.create!(user: member, achievement: Achievement.find_by!(slug: slug), earned_at: Time.current)
    end
    ActivityPresence.join(ActivityViewer.new(user: member), test_slug: "live-test")
  end

  def dismiss_tag_onboarding
    return unless page.has_css?(".onboarding", wait: 2)
    find(".onboarding__close").click
    expect(page).to have_no_css(".onboarding")
  end

  def open_card
    visit root_path
    dismiss_tag_onboarding
    find(".avatar-stack__item", match: :first).click
  end

  # Настоящий клик мышью по точке внутри элемента, свободной от карточки:
  # Capybara#click отказывается кликать под перекрытием, а нам нужно именно
  # поведение пользователя, который тыкает мимо поповера.
  def click_outside_card_on(selector, **options)
    target = find(selector, **options)
    rect = page.evaluate_script(
      "(() => { const r = arguments[0].getBoundingClientRect(); return [r.left, r.top, r.width, r.height] })()", target
    ) rescue nil
    rect ||= target.evaluate_script("(function(){ var r = this.getBoundingClientRect(); return [r.left, r.top, r.width, r.height] })()")
    left, top, width, height = rect
    x = left + width - 12
    y = top + height - 12
    page.driver.browser.mouse.click(x: x, y: y)
  end

  it "сразу показывает ачивки участника, а не пустой список" do
    open_card

    expect(page).to have_css(".viewer-card", text: "Бодрый Суслик")
    expect(page).to have_css(".viewer-card__count", text: "2")
    expect(page).to have_no_text("Пока нет открытых ачивок")
    expect(page).to have_css(".viewer-card__tile", count: 2)
  end

  it "показывает ачивки плитками, а название — в подсказке, как у тегов" do
    open_card
    expect(page).to have_css(".viewer-card__tile", count: 2)

    find(".viewer-card__tile", match: :first).hover

    expect(page).to have_css(".tag-tip__bubble--visible", text: /—/, wait: 4)
    expect(page).to have_no_css(".viewer-card .achievement")
  end

  it "подсказка с именем появляется при наведении на аватарку" do
    visit root_path
    dismiss_tag_onboarding

    find(".avatar-stack__item", match: :first).hover

    expect(page).to have_css(".tag-tip__bubble--visible", text: "Бодрый Суслик", wait: 4)
  end

  it "показывает одну плитку на лесенку и считает плитки" do
    UserAchievement.create!(user: member, achievement: Achievement.find_by!(slug: "ten_tests"), earned_at: Time.current)
    UserAchievement.create!(user: member, achievement: Achievement.find_by!(slug: "twenty_tests"), earned_at: Time.current)

    open_card

    # first_test, ten_tests и twenty_tests — одна лесенка: остаётся twenty_tests;
    # плюс perfect_score из другой группы.
    expect(page).to have_css(".viewer-card__tile", count: 2)
    expect(page).to have_css(".viewer-card__count", text: "2")
  end

  it "плейсхолдер нужного размера, пока ачивки грузятся" do
    allow_any_instance_of(ActivityUsersController).to receive(:show).and_wrap_original do |original, *args|
      sleep 1.5
      original.call(*args)
    end
    visit root_path
    dismiss_tag_onboarding
    find(".avatar-stack__item", match: :first).click

    expect(page).to have_css(".viewer-card__tile--skeleton", count: 2)
    expect(page).to have_css(".viewer-card__count", text: "2")
    expect(page).to have_css(".viewer-card__tile:not(.viewer-card__tile--skeleton)", count: 2, wait: 6)
  end

  it "не показывает кружок с числом на аватарке" do
    open_card

    expect(page).to have_no_css(".avatar-stack__badge")
  end

  it "прокрутка списка внутри карточки её не закрывает" do
    Achievement.shareable.where.not(id: member.achievements.select(:id)).find_each do |a|
      UserAchievement.create!(user: member, achievement: a, earned_at: Time.current)
    end
    open_card
    expect(page).to have_css(".viewer-card__tile", minimum: 10)

    page.execute_script(<<~JS)
      const list = document.querySelector(".viewer-card__list")
      list.scrollTop = list.scrollHeight
    JS

    expect(page).to have_css(".viewer-card")
    expect(page.evaluate_script("document.querySelector('.viewer-card__list').scrollTop")).to be_positive
  end

  it "карточка гостя встаёт вплотную к аватарке даже после большой карточки" do
    Achievement.shareable.where.not(id: member.achievements.select(:id)).find_each do |a|
      UserAchievement.create!(user: member, achievement: a, earned_at: Time.current)
    end
    guest = ActivityViewer.new(guest_token: "tok-1", guest_identity: { name: "Тихий Ёж", avatar_seed: "abcd1234" })
    ActivityPresence.join(guest, test_slug: "live-test")
    visit root_path
    dismiss_tag_onboarding

    find(".avatar-stack__item[aria-label^='Бодрый Суслик']").click
    expect(page).to have_css(".viewer-card__tile", minimum: 10)
    page.driver.browser.keyboard.type(:escape)
    expect(page).to have_no_css(".viewer-card")
    find(".avatar-stack__item[aria-label^='Тихий Ёж']").click
    expect(page).to have_css(".viewer-card__sub", text: "Гость")
    expect(page).to have_no_css(".viewer-card__title")

    gap = page.evaluate_script(<<~JS)
      (() => {
        const card   = document.querySelector(".viewer-card").getBoundingClientRect()
        const avatar = document.querySelector(".avatar-stack__item[aria-label^='Тихий Ёж']").getBoundingClientRect()
        return Math.abs(avatar.top - card.bottom)
      })()
    JS
    expect(gap).to be < 24
  end

  it "после гостя карточка участника показывает его ачивки, а не гостевую заглушку" do
    guest = ActivityViewer.new(guest_token: "tok-1", guest_identity: { name: "Тихий Ёж", avatar_seed: "abcd1234" })
    ActivityPresence.join(guest, test_slug: "live-test")

    visit root_path
    dismiss_tag_onboarding

    find(".avatar-stack__item[aria-label^='Тихий Ёж']").click
    expect(page).to have_css(".viewer-card__sub", text: "Гость")
    expect(page).to have_no_css(".viewer-card__title")
    page.driver.browser.keyboard.type(:escape)
    expect(page).to have_no_css(".viewer-card")

    find(".avatar-stack__item[aria-label^='Бодрый Суслик']").click

    expect(page).to have_css(".viewer-card", text: "Бодрый Суслик")
    expect(page).to have_css(".viewer-card__tile", count: 2)
    expect(page).to have_css(".viewer-card__sub", text: "Участник")
  end

  it "клик мимо карточки только закрывает её и не трогает элементы под курсором" do
    open_card
    expect(page).to have_css(".viewer-card__tile", count: 2)

    click_outside_card_on(".test-card", text: "Другой тест")

    expect(page).to have_no_css(".viewer-card")
    expect(page).to have_current_path("/")
  end

  it "клик по другой аватарке при открытой карточке тоже только закрывает её" do
    guest = ActivityViewer.new(guest_token: "tok-1", guest_identity: { name: "Тихий Ёж", avatar_seed: "abcd1234" })
    ActivityPresence.join(guest, test_slug: "live-test")
    visit root_path
    dismiss_tag_onboarding

    find(".avatar-stack__item[aria-label^='Бодрый Суслик']").click
    expect(page).to have_css(".viewer-card", text: "Бодрый Суслик")
    click_outside_card_on(".test-card", text: "Живой тест")

    expect(page).to have_no_css(".viewer-card")
    expect(page).to have_current_path("/")
  end

  it "Esc закрывает карточку" do
    open_card
    expect(page).to have_css(".viewer-card")

    page.driver.browser.keyboard.type(:escape)

    expect(page).to have_no_css(".viewer-card")
  end
end
