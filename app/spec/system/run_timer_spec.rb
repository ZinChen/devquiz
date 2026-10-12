require "rails_helper"

RSpec.describe "Таймер прохождения", type: :system, js: true do
  let(:repo_dir) { Rails.root.join("tmp/timer_repo") }

  before do
    FileUtils.mkdir_p(repo_dir)
    File.write(repo_dir.join("timer-test.yml"), {
      "slug" => "timer-test", "title" => "Тест таймера", "description" => "описание", "difficulty" => "basic",
      "questions" => [ { "id" => "q1", "text" => "Вопрос?", "type" => "single",
        "options" => [ { "id" => "a", "text" => "Да", "correct" => true },
                       { "id" => "b", "text" => "Нет", "correct" => false } ] } ]
    }.to_yaml)
    allow(TestSource).to receive(:repo_dir).and_return(repo_dir)
    allow(TestSource).to receive(:custom_dir).and_return(Rails.root.join("tmp/timer_custom_none"))
    YamlSyncService.sync_all
  end

  after { FileUtils.rm_rf(repo_dir) }

  def time_text
    find(".run-meter__time").text
  end

  def seconds
    min, sec = time_text.split(":").map(&:to_i)
    min * 60 + sec
  end

  def hide_tab
    page.execute_script(<<~JS)
      Object.defineProperty(document, "hidden", { configurable: true, get: () => true })
      document.dispatchEvent(new Event("visibilitychange"))
    JS
  end

  def show_tab
    page.execute_script(<<~JS)
      Object.defineProperty(document, "hidden", { configurable: true, get: () => false })
      document.dispatchEvent(new Event("visibilitychange"))
    JS
  end

  def open_run
    visit "/tests/timer-test/run/new"
    expect(page).to have_css(".run-meter__time")
  end

  it "идёт, пока вкладка видна" do
    open_run
    before = seconds

    sleep 2.3

    expect(seconds).to be >= before + 2
  end

  it "стоит, пока вкладка скрыта, и показывает паузу" do
    open_run
    sleep 1.2
    hide_tab
    expect(page).to have_css(".run-meter__pause", text: "пауза")
    frozen = time_text

    sleep 2.5

    expect(time_text).to eq(frozen)
  end

  it "продолжает с того же места после возврата на вкладку" do
    open_run
    sleep 1.2
    hide_tab
    frozen = seconds
    sleep 2.5
    show_tab

    expect(page).to have_no_css(".run-meter__pause")
    sleep 1.3

    # Скрытые 2.5 секунды в счёт не вошли: прибавилась только секунда-другая.
    expect(seconds).to be_between(frozen, frozen + 3)
  end

  it "после пяти минут без действий встаёт на паузу и вычитает бездействие" do
    open_run
    sleep 1.1
    # Часы страницы уходят на шесть минут вперёд: следующий тик увидит, что
    # действий не было дольше порога (ждать по-настоящему незачем).
    page.execute_script(<<~JS)
      const realNow = Date.now.bind(Date)
      window.__offset = 6 * 60 * 1000
      Date.now = () => realNow() + window.__offset
    JS

    expect(page).to have_css(".run-meter__pause", text: "пауза", wait: 4)
    # Пять минут бездействия вычтены, а накопленных секунд меньше пяти минут.
    expect(time_text).to eq("00:00")
  end

  it "любое действие снимает паузу по бездействию" do
    open_run
    page.execute_script(<<~JS)
      const realNow = Date.now.bind(Date)
      window.__offset = 6 * 60 * 1000
      Date.now = () => realNow() + window.__offset
    JS
    expect(page).to have_css(".run-meter__pause", wait: 4)

    page.execute_script('window.dispatchEvent(new Event("pointermove"))')

    expect(page).to have_no_css(".run-meter__pause")
  end

  it "не запускает отсчёт заново при обновлении страницы с ответами" do
    open_run
    find(".option", text: "Да").click
    sleep 2.3
    saved = seconds

    page.refresh
    expect(page).to have_css(".run-meter__time")

    expect(seconds).to be >= saved - 1
  end
end
