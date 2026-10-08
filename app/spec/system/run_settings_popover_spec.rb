require "rails_helper"

RSpec.describe "Настройки прохождения", type: :system, js: true do
  let(:repo_dir) { Rails.root.join("tmp/settings_repo") }

  before do
    FileUtils.mkdir_p(repo_dir)
    File.write(repo_dir.join("settings-test.yml"), {
      "slug" => "settings-test", "title" => "Тест настроек", "description" => "описание", "difficulty" => "basic",
      "questions" => [ { "id" => "q1", "text" => "Вопрос?", "type" => "single",
        "options" => [ { "id" => "a", "text" => "Да", "correct" => true },
                       { "id" => "b", "text" => "Нет", "correct" => false } ] } ]
    }.to_yaml)
    allow(TestSource).to receive(:repo_dir).and_return(repo_dir)
    allow(TestSource).to receive(:custom_dir).and_return(Rails.root.join("tmp/settings_custom_none"))
    YamlSyncService.sync_all
  end

  after { FileUtils.rm_rf(repo_dir) }

  def open_run
    visit "/tests/settings-test/run/new"
    expect(page).to have_css(".run-header__settings-btn")
  end

  # Настоящий клик мышью по точке внутри элемента (Capybara#click отказывается
  # кликать под перекрытием, а нужно поведение пользователя).
  def real_click_on(selector, **options)
    target = find(selector, **options)
    left, top, width, height = target.evaluate_script(
      "(() => { const r = this.getBoundingClientRect(); return [r.left, r.top, r.width, r.height] })()"
    )
    page.driver.browser.mouse.click(x: left + width / 2, y: top + height / 2)
  end

  it "открывается поповером под шестерёнкой, а не сдвигает вопросы" do
    open_run
    before_top = find(".option", match: :first).evaluate_script("this.getBoundingClientRect().top")

    find(".run-header__settings-btn").click

    expect(page).to have_css(".settings-panel", text: "Настройки прохождения")
    after_top = find(".option", match: :first, visible: :all).evaluate_script("this.getBoundingClientRect().top")
    expect(after_top).to eq(before_top)
  end

  it "клик мимо закрывает панель и больше ничего не делает" do
    open_run
    find(".run-header__settings-btn").click
    expect(page).to have_css(".settings-panel")

    real_click_on(".option", text: "Да")

    expect(page).to have_no_css(".settings-panel")
    expect(page).to have_css(".run-header__progress", text: "0 / 1")
  end

  it "Esc закрывает панель" do
    open_run
    find(".run-header__settings-btn").click
    expect(page).to have_css(".settings-panel")

    page.driver.browser.keyboard.type(:escape)

    expect(page).to have_no_css(".settings-panel")
  end

  it "повторный клик по шестерёнке закрывает панель" do
    open_run
    real_click_on(".run-header__settings-btn")
    expect(page).to have_css(".settings-panel")

    real_click_on(".run-header__settings-btn")

    expect(page).to have_no_css(".settings-panel")
  end

  it "переключение режима внутри панели работает и не закрывает её" do
    open_run
    find(".run-header__settings-btn").click

    find(".settings-option", text: "По одному вопросу").click

    expect(page).to have_css(".settings-panel")
    expect(page).to have_css(".question-card")
  end
end
