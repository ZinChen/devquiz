require "rails_helper"

RSpec.describe "Navigation", type: :system, js: true do
  before { driven_by :cuprite }

  # Создаём тест прямо в before чтобы данные были видны браузеру (truncation стратегия)
  before(:each) do
    @test_meta = create(:test_metadatum, title: "Ruby основы", slug: "ror-basics")
  end

  describe "главная страница" do
    it "загружается и показывает список тестов" do
      visit root_path
      expect(page).to have_text("Тесты для разработчиков")
      expect(page).to have_text("Ruby основы")
    end

    it "переход на страницу теста по клику" do
      visit root_path
      find("a", text: "Ruby основы").click
      expect(page).to have_current_path(%r{/tests/ror-basics})
      expect(page).to have_text("Ruby основы")
    end
  end

  describe "страница теста" do
    it "загружается и показывает ссылку назад" do
      visit test_path(@test_meta.slug)
      expect(page).to have_text("Ruby основы")
      expect(page).to have_link("← Все тесты", href: "/")
    end

    it "переход назад на главную через ← Все тесты" do
      visit test_path(@test_meta.slug)
      find("a", text: "← Все тесты").click
      expect(page).to have_current_path("/")
      expect(page).to have_text("Тесты для разработчиков")
    end

    it "переход на страницу прохождения" do
      visit test_path(@test_meta.slug)
      find("a", text: "Начать тест").click
      expect(page).to have_current_path(%r{/tests/ror-basics/run/new})
    end
  end

  describe "страница статистики" do
    it "загружается по прямому переходу" do
      visit stats_path
      expect(page).to have_current_path(stats_path)
      expect(page).to have_text("Общая статистика")
    end
  end
end
