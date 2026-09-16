require "rails_helper"

RSpec.describe TopicIndex do
  it "находит тесты, где есть вопросы по теме" do
    expect(described_class.tests_for("mvc")).to include("ror-basics")
  end

  # Ради этого индекс и появился: такие темы в tags тестов не встречаются,
  # и поиск по тегам их не находил.
  it "находит темы, которых нет в тегах тестов" do
    expect(described_class.tests_for("queries")).not_to be_empty
    expect(described_class.tests_for("indexes")).not_to be_empty
  end

  it "ставит вперёд тест с большим числом вопросов по теме" do
    slugs = described_class.tests_for("mvc")
    counts = slugs.map { |s| described_class.question_ids_for("mvc")[s].size }

    expect(counts).to eq(counts.sort.reverse)
  end

  it "отдаёт id вопросов по тестам" do
    ids = described_class.question_ids_for("mvc")["ror-basics"]

    expect(ids).to include("q1", "q2")
  end

  # Индекс заморожен, и default_proc на внутренних хэшах роняет чтение
  # отсутствующего ключа с FrozenError — так упала тренировка по теме.
  it "безопасно читает тест, которого нет в теме" do
    by_test = described_class.question_ids_for("mvc")

    expect { by_test["postgresql-basics"] }.not_to raise_error
    expect(by_test["postgresql-basics"]).to be_nil
  end

  it "не отдаёт хэши с default_proc" do
    by_test = described_class.question_ids_for("mvc")

    expect(by_test.default_proc).to be_nil
  end

  it "возвращает пусто для незнакомой темы" do
    expect(described_class.tests_for("нет-такой-темы")).to eq([])
    expect(described_class.question_ids_for("нет-такой-темы")).to eq({})
  end

  it "не считает словарь тем за тест" do
    expect(described_class.tests_for("mvc")).not_to include("topics")
  end

  it "знает темы конкретного теста" do
    expect(described_class.topics_of("ror-basics")).to include("mvc", "controllers")
  end
end
