require "rails_helper"

RSpec.describe "Сортировка тестов на главной", type: :system, js: true do
  before { driven_by :cuprite }

  before(:each) do
    create(:test_metadatum, slug: "b-test", title: "Бета тест",   attempts_count: 5,  difficulty: "expert",
                             created_at: 2.days.ago)
    create(:test_metadatum, slug: "a-test", title: "Альфа тест",  attempts_count: 20, difficulty: "basic",
                             created_at: 3.days.ago)
    create(:test_metadatum, slug: "c-test", title: "Гамма тест",  attempts_count: 1,  difficulty: "advanced",
                             created_at: 1.day.ago)
  end

  def dismiss_tag_onboarding
    return unless page.has_css?(".onboarding", wait: 2)
    find(".onboarding__close").click
    expect(page).to have_no_css(".onboarding")
  end

  def open_sort_menu
    find(".sort-menu__icon").click
  end

  def select_sort(label)
    open_sort_menu
    find(".sort-menu__option", text: label).click
  end

  def visible_titles
    all(".test-card__title", visible: :visible).map { |el| el.text.split("\n").first }
  end

  it "по умолчанию сортирует по популярности" do
    visit root_path
    dismiss_tag_onboarding

    expect(visible_titles).to eq([ "Альфа тест", "Бета тест", "Гамма тест" ])
  end

  it "сортирует по новизне" do
    visit root_path
    dismiss_tag_onboarding

    select_sort("По новизне")

    expect(visible_titles).to eq([ "Гамма тест", "Бета тест", "Альфа тест" ])
  end

  it "сортирует по алфавиту" do
    visit root_path
    dismiss_tag_onboarding

    select_sort("По алфавиту")

    expect(visible_titles).to eq([ "Альфа тест", "Бета тест", "Гамма тест" ])
  end

  it "сортирует по сложности" do
    visit root_path
    dismiss_tag_onboarding

    select_sort("По сложности")

    expect(visible_titles).to eq([ "Альфа тест", "Гамма тест", "Бета тест" ])
  end

  it "запоминает выбранную сортировку между визитами" do
    visit root_path
    dismiss_tag_onboarding

    select_sort("По алфавиту")
    expect(visible_titles).to eq([ "Альфа тест", "Бета тест", "Гамма тест" ])

    visit root_path
    dismiss_tag_onboarding

    expect(page).to have_css(".sort-menu__icon")
    open_sort_menu
    expect(find(".sort-menu__option", text: "По алфавиту")[:class]).to include("sort-menu__option--active")
  end
end
