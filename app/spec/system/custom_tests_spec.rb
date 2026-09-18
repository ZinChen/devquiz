require "rails_helper"

RSpec.describe "Локальные тесты из tests_custom", type: :system, js: true do
  before { driven_by :cuprite }

  let(:repo_dir)   { Rails.root.join("tmp/badge_repo") }
  let(:custom_dir) { Rails.root.join("tmp/badge_custom") }

  def write(dir, slug, title)
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, "#{slug}.yml"), {
      "slug" => slug, "title" => title, "description" => "описание", "difficulty" => "beginner",
      "questions" => [ { "id" => "q1", "text" => "Вопрос?", "type" => "single",
        "options" => [ { "id" => "a", "text" => "Да", "correct" => true },
                       { "id" => "b", "text" => "Нет", "correct" => false } ] } ]
    }.to_yaml)
  end

  before do
    write(repo_dir,   "repo-only",   "Обычный тест")
    write(repo_dir,   "shadowed",    "Репозиторная версия")
    write(custom_dir, "shadowed",    "Подменённая версия")
    write(custom_dir, "custom-only", "Локальный тест")

    allow(TestSource).to receive(:repo_dir).and_return(repo_dir)
    allow(TestSource).to receive(:custom_dir).and_return(custom_dir)
    YamlSyncService.sync_all
  end

  after { FileUtils.rm_rf([ repo_dir, custom_dir ]) }

  it "показывает «Локальный», «Подменяет» и ничего для репозиторного" do
    visit root_path
    if page.has_css?(".onboarding", wait: 2)
      find(".onboarding__close").click
      expect(page).to have_no_css(".onboarding")
    end

    expect(page).to have_text("Обычный тест")
    expect(page).to have_text("Подменённая версия")
    expect(page).to have_no_text("Репозиторная версия")

    local  = find(".test-card", text: "Локальный тест")
    shadow = find(".test-card", text: "Подменённая версия")
    plain  = find(".test-card", text: "Обычный тест")

    expect(local).to have_css(".custom-badge", text: "Локальный")
    expect(shadow).to have_css(".custom-badge--override", text: "Подменяет")
    expect(plain).to have_no_css(".custom-badge")
  end

  it "сохраняет попытку — в отличие от разового теста из drag & drop" do
    visit root_path
    if page.has_css?(".onboarding", wait: 2)
      find(".onboarding__close").click
      expect(page).to have_no_css(".onboarding")
    end

    expect {
      find(".test-card__title", text: "Локальный тест").click
      expect(page).to have_text("Вопрос?")
      find(".option__text", text: "Да", exact_text: true).click
      click_button "Завершить тест"
      expect(page).to have_text("Разбор ответов")
    }.to change { TestAttempt.where(test_slug: "custom-only").count }.by(1)

    expect(page).to have_text("100%")
    expect(page).to have_no_text("результат нигде не сохранён")
  end
end
