require "rails_helper"

RSpec.describe TopicDictionary do
  it "читает темы из tests/topics.yml" do
    expect(described_class.slugs).to include("mvc", "indexes", "docker")
  end

  it "отдаёт название, описание и цвет темы" do
    topic = described_class.find("mvc")

    expect(topic.label).to eq("MVC & Request lifecycle")
    expect(topic.description).to be_present
    expect(topic.color).to match(/\A#[0-9A-Fa-f]{6}\z/)
  end

  it "знает только объявленные темы" do
    expect(described_class.known?("mvc")).to be true
    expect(described_class.known?("нет-такой-темы")).to be false
  end

  # Теги тестов (ruby, rails) в словаре тем не объявлены, но попадают в отчёт
  # как запасной вариант — они должны доезжать до фронта как есть.
  it "не теряет незнакомый слаг, а показывает его как подпись" do
    topic = described_class.decorate([ "ruby" ]).first

    expect(topic.slug).to eq("ruby")
    expect(topic.label).to eq("ruby")
    expect(topic.color).to be_nil
  end

  it "сохраняет порядок переданных тем" do
    labels = described_class.decorate(%w[indexes mvc]).map(&:slug)

    expect(labels).to eq(%w[indexes mvc])
  end
end
