require "rails_helper"

RSpec.describe "Сейчас проходят на странице теста", type: :system, js: true do
  let!(:meta)   { create(:test_metadatum, slug: "live-test", title: "Живой тест") }
  let(:member)  { create(:user, name: "Бодрый Суслик") }
  let(:guest)   { ActivityViewer.new(guest_token: "tok-1", guest_identity: { name: "Тихий Ёж", avatar_seed: "abcd1234" }) }

  def join(viewer)
    ActivityPresence.join(viewer, test_slug: "live-test")
  end

  it "не показывает блок, пока никто не проходит" do
    visit "/tests/live-test"
    expect(page).to have_css(".test-detail__title")

    expect(page).to have_no_css(".test-detail__live")
  end

  it "показывает аватарки проходящих, участников и гостей, без числа" do
    join(ActivityViewer.new(user: member))
    join(guest)

    visit "/tests/live-test"

    expect(page).to have_css(".test-detail__live-label", text: "Сейчас проходят")
    expect(page).to have_css(".test-detail__live .avatar-stack__item", count: 2)
    expect(page).to have_no_text("человека")
  end

  it "не показывает скрывшего активность" do
    member.update!(activity_visible: false)
    join(ActivityViewer.new(user: member))
    join(guest)

    visit "/tests/live-test"

    expect(page).to have_css(".test-detail__live .avatar-stack__item", count: 1)
    expect(page).to have_no_css(".avatar-stack__item[aria-label^='Бодрый Суслик']")
  end

  it "не показывает тех, кто проходит другой тест" do
    create(:test_metadatum, slug: "other-test", title: "Другой")
    ActivityPresence.join(ActivityViewer.new(user: member), test_slug: "other-test")

    visit "/tests/live-test"
    expect(page).to have_css(".test-detail__title")

    expect(page).to have_no_css(".test-detail__live")
  end

  it "карточка участника открывается по клику на аватарку" do
    join(ActivityViewer.new(user: member))

    visit "/tests/live-test"
    find(".test-detail__live .avatar-stack__item", match: :first).click

    expect(page).to have_css(".viewer-card", text: "Бодрый Суслик")
  end
end
