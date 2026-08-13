require "rails_helper"

RSpec.describe "Тест из перетащенного файла", type: :system, js: true do
  before { driven_by :cuprite }

  before(:each) { create(:test_metadatum, title: "Ruby основы", slug: "ror-basics") }

  def dismiss_tag_onboarding
    return unless page.has_css?(".onboarding", wait: 2)
    find(".onboarding__close").click
    expect(page).to have_no_css(".onboarding")
  end

  # Перетаскивание файла из ОС в headless-браузер не воспроизвести кликами:
  # собираем DataTransfer вручную и диспатчим тот же drop-событие, что
  # прилетело бы от мыши. По умолчанию бросаем в шапку — она вне контента,
  # и так проверяется, что файл принимает вся страница.
  def drop_yaml(content, target = "header.layout__header")
    page.execute_script(<<~JS, content, target)
      const [content, selector] = arguments
      const file = new File([content], "dropped.yml", { type: "text/yaml" })
      const dt = new DataTransfer()
      dt.items.add(file)
      document.querySelector(selector).dispatchEvent(
        new DragEvent("drop", { dataTransfer: dt, bubbles: true, cancelable: true }))
    JS
  end

  # Текст варианта лежит во вложенном .option__text: в самом label есть ещё
  # буква варианта, и по нему точное совпадение не поймать.
  let(:pick) { ->(text) { find(".option__text", text: text, exact_text: true).click } }

  let(:valid_yaml) do
    <<~YML
      title: "Тест из файла"
      description: "проверка"
      questions:
        - id: q1
          text: "Сколько будет 2+2?"
          type: single
          options:
            - { id: a, text: "Четыре", correct: true }
            - { id: b, text: "Пять", correct: false }
          explanation: "Это арифметика"
        - id: q2
          text: "Выбери чётные"
          type: multiple
          options:
            - { id: a, text: "2", correct: true }
            - { id: b, text: "3", correct: false }
            - { id: c, text: "4", correct: true }
    YML
  end

  it "открывает тест, показывает результат и не пишет попытку в базу" do
    visit root_path
    dismiss_tag_onboarding

    expect { drop_yaml(valid_yaml) }.not_to change(TestAttempt, :count)

    expect(page).to have_text("Тест из файла")
    expect(page).to have_text("Сколько будет 2+2?")
    expect(page).to have_text(/результат не попадёт в статистику/i)

    # Отвечаем верно на оба вопроса и отправляем.
    pick.("Четыре")
    pick.("2")
    pick.("4")

    expect {
      click_button("Завершить тест")
      expect(page).to have_text("Разбор ответов")
    }.not_to change(TestAttempt, :count)

    expect(page).to have_text("100%")
    expect(page).to have_text("2 правильных из 2")
    expect(page).to have_text("Тест из файла — результат нигде не сохранён")
    expect(page).to have_button("Сохранить результат")
    expect(page).to have_text("Это арифметика")
  end

  it "открывает второй файл чистым, а не с ответами первого" do
    visit root_path
    dismiss_tag_onboarding

    drop_yaml(valid_yaml)
    expect(page).to have_text("Сколько будет 2+2?")

    pick.("Четыре")
    pick.("2")
    pick.("4")
    click_button "Завершить тест"
    expect(page).to have_text("Разбор ответов")

    # Возвращаемся на главную и бросаем другой файл.
    click_link "Все тесты"
    expect(page).to have_text("Тесты для разработчиков")

    drop_yaml(<<~YML)
      title: "Второй тест"
      questions:
        - id: q1
          text: "Столица Франции?"
          type: single
          options:
            - { id: a, text: "Париж", correct: true }
            - { id: b, text: "Лион", correct: false }
    YML

    expect(page).to have_text("Столица Франции?")
    # Ни одного отвеченного вопроса и никакого разбора от прошлого прохождения.
    expect(page).to have_text("0 / 1")
    expect(page).to have_no_text("Разбор ответов")
    expect(page).to have_no_text("Сколько будет 2+2?")
  end

  it "принимает файл, брошенный на шапку страницы" do
    visit root_path
    dismiss_tag_onboarding

    drop_yaml(valid_yaml, "header.layout__header")

    expect(page).to have_text("Тест из файла")
    expect(page).to have_text("Сколько будет 2+2?")
  end

  it "принимает файл, брошенный на подвал страницы" do
    visit root_path
    dismiss_tag_onboarding

    drop_yaml(valid_yaml, "footer.layout__footer")

    expect(page).to have_text("Сколько будет 2+2?")
  end

  it "показывает ошибки, если структура файла неверная" do
    visit root_path
    dismiss_tag_onboarding

    drop_yaml(<<~YML)
      title: "Кривой тест"
      questions:
        - id: q1
          text: "Без единого правильного ответа"
          type: single
          options:
            - { id: a, text: "нет", correct: false }
            - { id: b, text: "тоже нет", correct: false }
    YML

    expect(page).to have_text("Файл не подходит")
    expect(page).to have_text(/не отмечен ни один правильный вариант/i)
    expect(page).to have_current_path("/")
  end

  it "не принимает файл с неразбираемым YAML" do
    visit root_path
    dismiss_tag_onboarding

    drop_yaml("title: [не закрытая скобка\n  questions:")

    expect(page).to have_text("Файл не подходит")
    expect(page).to have_text(/не удалось разобрать yaml/i)
  end
end
