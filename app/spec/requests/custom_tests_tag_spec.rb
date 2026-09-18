require 'rails_helper'

RSpec.describe "Тег custom у локальных тестов", type: :request do
  def tags_of(slug)
    get root_path
    props = JSON.parse(response.body[/data-page="([^"]+)"/, 1].then { |raw| CGI.unescapeHTML(raw) })
    props.dig("props", "tests").find { |t| t["slug"] == slug }&.fetch("tags")
  end

  it "добавляет тег custom тесту из tests_custom/" do
    create(:test_metadatum, slug: "local-one", tags: "ruby", source: TestSource::CUSTOM)

    expect(tags_of("local-one")).to include("custom")
  end

  it "не добавляет тег репозиторному тесту" do
    create(:test_metadatum, slug: "repo-one", tags: "ruby", source: TestSource::REPO)

    expect(tags_of("repo-one")).not_to include("custom")
  end

  it "не дублирует тег, если он уже написан в yaml" do
    create(:test_metadatum, slug: "dup-tag", tags: "ruby,custom", source: TestSource::CUSTOM)

    expect(tags_of("dup-tag").count("custom")).to eq(1)
  end

  it "соседствует с синтетическим тегом code" do
    create(:test_metadatum, slug: "both", tags: "ruby",
                            source: TestSource::CUSTOM, has_code_challenge: true)

    expect(tags_of("both")).to include("custom", "code", "ruby")
  end
end
