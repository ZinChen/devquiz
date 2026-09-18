require "rails_helper"

RSpec.describe "Кнопка «Снять» в строке тегов", type: :system, js: true do
  before { driven_by :cuprite }

  before(:each) do
    create(:test_metadatum, slug: "ruby-one", title: "Тест про Ruby",   tags: "ruby")
    create(:test_metadatum, slug: "pg-one",   title: "Тест про Postgres", tags: "postgresql")
  end

  def dismiss_tag_onboarding
    return unless page.has_css?(".onboarding", wait: 2)
    find(".onboarding__close").click
    expect(page).to have_no_css(".onboarding")
  end

  def tag_filter(name)
    find(".tag-filter-btn", text: /\A#{Regexp.escape(name)}\b/)
  end

  def ctrl_click_tag(name)
    page.execute_script(<<~JS, name)
      const label = arguments[0]
      const btn = [...document.querySelectorAll('.tag-filter-btn')]
        .find(e => e.textContent.trim().startsWith(label))
      btn.dispatchEvent(new MouseEvent('click', { ctrlKey: true, bubbles: true, cancelable: true }))
    JS
  end

  it "появляется только когда есть выделенные теги" do
    visit root_path
    dismiss_tag_onboarding

    expect(page).to have_no_button("Снять")

    tag_filter("ruby").click

    expect(page).to have_button("Снять")
  end

  it "снимает выделение и возвращает все тесты в выдачу" do
    visit root_path
    dismiss_tag_onboarding

    tag_filter("ruby").click
    expect(page).to have_text("Тест про Ruby")
    expect(page).to have_no_text("Тест про Postgres")

    click_button "Снять"

    expect(page).to have_text("Тест про Ruby")
    expect(page).to have_text("Тест про Postgres")
    expect(page).to have_no_button("Снять")
  end

  it "снимает и исключённые теги тоже" do
    visit root_path
    dismiss_tag_onboarding

    # Ctrl+клик исключает тег. Модификатор Capybara до Cuprite не доезжает,
    # поэтому шлём то же событие вручную — проверяем реакцию приложения.
    ctrl_click_tag("ruby")
    expect(page).to have_css(".tag-filter--excluded")

    click_button "Снять"

    expect(page).to have_no_css(".tag-filter--excluded")
    expect(page).to have_text("Тест про Ruby")
  end

  it "не сохраняет снятие на сервер — оно только на этой странице" do
    visit root_path
    dismiss_tag_onboarding
    tag_filter("ruby").click

    # Предпочтения сохраняются через router.patch (XHR), поэтому перехватываем
    # XMLHttpRequest: «Снять» не должна обращаться к серверу вовсе — иначе
    # выбор пропал бы и при следующем заходе.
    page.execute_script(<<~JS)
      window.__calls = []
      const open = XMLHttpRequest.prototype.open
      XMLHttpRequest.prototype.open = function (method, url) {
        window.__calls.push(method + " " + url)
        return open.apply(this, arguments)
      }
    JS

    click_button "Снять"
    expect(page).to have_no_button("Снять")

    expect(page.evaluate_script("window.__calls")).to be_empty
  end

  it "не трогает поиск и сложность — у них свои контролы" do
    visit root_path
    dismiss_tag_onboarding

    find(".search-toggle__icon").click
    fill_in_search = find(".search-input")
    fill_in_search.set("Ruby")
    tag_filter("ruby").click

    click_button "Снять"

    expect(find(".search-input").value).to eq("Ruby")
  end
end
