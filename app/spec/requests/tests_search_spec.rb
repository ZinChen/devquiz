require "rails_helper"

RSpec.describe "Поиск тестов на главной: теги и темы с переводом", type: :request do
  # Реальный тест из репозитория, у которого вопросы размечены хотя бы одной
  # темой, — topics живут в YAML и не создаются фабрикой, поэтому для
  # проверки перевода нужен настоящий файл, а не произвольный слаг.
  let(:topic_slug)  { TopicDictionary.topics.keys.first }
  let(:test_slug)   { TopicIndex.current.tests_for(topic_slug).first }
  let!(:meta)       { create(:test_metadatum, slug: test_slug, difficulty: "basic") }

  def index_props
    get "/tests", headers: { "X-Inertia" => "true" }
    response.parsed_body["props"]
  end

  def test_props_for(slug)
    index_props["tests"].find { |t| t["slug"] == slug }
  end

  it "отдаёт темы вопросов теста отдельно от тегов" do
    props = test_props_for(test_slug)

    expect(props["topics"]).to include(topic_slug)
  end

  it "переводит тему в русский label из tests/topics.yml" do
    props = test_props_for(test_slug)
    label = TopicDictionary.label_for(topic_slug)

    expect(props["topics_translated"]).to include(label)
  end

  it "переводит теги через описание из tag_taxonomy.yml" do
    other = create(:test_metadatum, slug: "search-tags-test", tag_list: "backend")
    description = TagTaxonomy.description_of("backend")

    props = test_props_for(other.slug)

    expect(description).to be_present
    expect(props["tags_translated"]).to include(description)
  end

  it "не ломается на тесте без вопросов в YAML-индексе (topics пустой)" do
    orphan = create(:test_metadatum, slug: "no-such-file-on-disk")

    props = test_props_for(orphan.slug)

    expect(props["topics"]).to eq([])
    expect(props["topics_translated"]).to eq([])
  end
end
