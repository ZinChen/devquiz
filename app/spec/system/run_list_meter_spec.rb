require "rails_helper"

RSpec.describe "Счётчик и время в режиме списка", type: :system, js: true do
  let(:repo_dir) { Rails.root.join("tmp/meter_repo") }

  before do
    FileUtils.mkdir_p(repo_dir)
    questions = (1..12).map do |i|
      { "id" => "q#{i}", "text" => "Вопрос #{i}?", "type" => "single",
        "options" => [ { "id" => "a", "text" => "Да", "correct" => true },
                       { "id" => "b", "text" => "Нет", "correct" => false } ] }
    end
    File.write(repo_dir.join("meter-test.yml"), {
      "slug" => "meter-test", "title" => "Тест счётчика", "description" => "описание",
      "difficulty" => "basic", "questions" => questions
    }.to_yaml)
    allow(TestSource).to receive(:repo_dir).and_return(repo_dir)
    allow(TestSource).to receive(:custom_dir).and_return(Rails.root.join("tmp/meter_custom_none"))
    YamlSyncService.sync_all
  end

  after { FileUtils.rm_rf(repo_dir) }

  def meter_top
    page.evaluate_script("document.querySelector('.run-meter__card').getBoundingClientRect().top")
  end

  it "остаётся на экране при прокрутке страницы" do
    visit "/tests/meter-test/run/new"
    expect(page).to have_css(".run-meter__time")

    page.execute_script("window.scrollTo(0, document.body.scrollHeight)")
    sleep 0.2

    expect(meter_top).to be_between(0, 120)
    expect(page).to have_css(".run-meter__time", text: /\d\d:\d\d/)
  end

  it "стоит справа от колонки вопросов" do
    visit "/tests/meter-test/run/new"
    expect(page).to have_css(".run-meter__card")

    meter_left = page.evaluate_script("document.querySelector('.run-meter__card').getBoundingClientRect().left")
    content_right = page.evaluate_script("document.querySelector('.all-at-once__content').getBoundingClientRect().right")

    expect(meter_left).to be > content_right
  end

  it "на узком экране становится липкой плашкой у верхнего края" do
    page.driver.resize(800, 800)
    visit "/tests/meter-test/run/new"
    expect(page).to have_css(".run-meter__time")

    page.execute_script("window.scrollTo(0, document.body.scrollHeight)")
    sleep 0.2

    expect(meter_top).to be_between(0, 120)
    right = page.evaluate_script("document.querySelector('.run-meter__card').getBoundingClientRect().right")
    expect(right).to be <= 800
  end

  it "не дублирует счётчик в шапке страницы" do
    visit "/tests/meter-test/run/new"
    expect(page).to have_css(".run-meter__progress", text: "0 / 12")

    expect(page).to have_no_css(".run-header__progress")
  end

  it "в режиме по одному вопросу счётчик остаётся в шапке" do
    visit "/tests/meter-test/run/new"
    find(".run-header__settings-btn").click
    find(".settings-option", text: "По одному вопросу").click
    find(".anchored-popover__backdrop", visible: :all).click(x: 5, y: 5) rescue page.driver.browser.keyboard.type(:escape)

    expect(page).to have_css(".run-header__progress", text: "0 / 12")
    expect(page).to have_no_css(".run-meter")
  end
end
