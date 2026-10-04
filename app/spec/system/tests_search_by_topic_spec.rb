require "rails_helper"

RSpec.describe "Поиск тестов по переведённой теме вопроса", type: :system, js: true do
  # ruby-runtime-advanced-1 — реальный файл из tests/, у части вопросов
  # которого topics: [mvc]. mvc переводится в tests/topics.yml как «MVC &
  # Request lifecycle» — слово "lifecycle" не встречается ни в заголовке, ни
  # в описании, ни в тегах этого теста, только в переводе темы. Так
  # доказывается, что находит именно новый канал поиска, а не старые поля.
  # Слаг не ror-basics: он занят другими system-спеками (navigation_spec,
  # dropped_test_spec) с другим заголовком, и уникальный индекс на slug не
  # даёт создать здесь свою запись с тем же слагом поверх их.
  let!(:meta) do
    create(:test_metadatum, slug: "ruby-runtime-advanced-1", title: "Ruby: рантайм и конкурентность")
  end

  def dismiss_tag_onboarding
    return unless page.has_css?(".onboarding", wait: 2)
    find(".onboarding__close").click
    expect(page).to have_no_css(".onboarding")
  end

  # Заголовок страницы ("Тесты для разработчиков" / подзаголовок "Ruby on
  # Rails, Go, PostgreSQL...") сам по себе содержит текст запроса/названия
  # теста, поэтому проверяем карточку внутри списка (.test-card), а не всю
  # страницу — иначе статический подзаголовок маскирует реальный результат
  # фильтрации.
  it "находит тест по русскому переводу темы, отсутствующему в заголовке и описании" do
    visit root_path
    dismiss_tag_onboarding

    find(".search-toggle__icon").click
    fill_in placeholder: "Поиск...", with: "lifecycle"

    expect(page).to have_css(".test-card", text: "Ruby: рантайм и конкурентность")
  end

  it "не находит тест по слову, которого нет ни в одном поле" do
    visit root_path
    dismiss_tag_onboarding

    find(".search-toggle__icon").click
    fill_in placeholder: "Поиск...", with: "совершенно-случайная-строка-xyz"

    expect(page).to have_no_css(".test-card")
    expect(page).to have_content("Тесты не найдены")
  end
end
