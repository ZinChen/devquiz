require "rails_helper"

RSpec.describe "Поиск на главной переживает навигацию", type: :system, js: true do
  before(:each) do
    create(:test_metadatum, slug: "search-persist-ruby", title: "Надёжный тест", tags: "ruby")
  end

  def dismiss_tag_onboarding
    return unless page.has_css?(".onboarding", wait: 2)
    find(".onboarding__close").click
    expect(page).to have_no_css(".onboarding")
  end

  it "остаётся развёрнутым и видимым после возврата на страницу" do
    visit root_path
    dismiss_tag_onboarding

    find(".search-toggle__icon").click
    fill_in placeholder: "Поиск...", with: "Надёжный"
    expect(page).to have_content("Надёжный тест")

    # Уходим на другую страницу тем же приложением (Inertia-переход) и
    # возвращаемся кнопкой «назад» — тем самым сценарием, в котором поле
    # с непустым запросом рисовалось нулевой ширины: searchQuery пережил
    # переход (он живёт на уровне модуля), а searchOpen — локальный для
    # нового маунта компонента и раньше всегда стартовал закрытым.
    visit "/tests/search-persist-ruby"
    page.go_back

    expect(page).to have_css(".search-toggle--open")
    expect(find(".search-input").value).to eq("Надёжный")
  end
end
