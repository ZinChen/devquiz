require 'rails_helper'

RSpec.describe YamlSyncService do
  let(:yaml_content) do
    {
      "slug" => "test-quiz",
      "title" => "Test Quiz",
      "description" => "A test quiz",
      "difficulty" => "beginner",
      "estimated_time" => 10,
      "tags" => [ "rails", "ruby" ],
      "questions" => [
        {
          "id" => "q1",
          "text" => "What is Rails?",
          "type" => "single",
          "options" => [
            { "id" => "a", "text" => "A framework", "correct" => true },
            { "id" => "b", "text" => "A language", "correct" => false }
          ]
        }
      ]
    }
  end

  let(:tests_dir)  { Rails.root.join("tmp/sync_spec_tests") }
  let(:yaml_path)  { tests_dir.join("test-quiz.yml") }

  before do
    FileUtils.mkdir_p(tests_dir)
    File.write(yaml_path, yaml_content.to_yaml)
    # Пути знает TestSource, поэтому подменяем их там: TESTS_DIR остался только
    # для topics.yml и больше не участвует в поиске тестов.
    allow(TestSource).to receive(:repo_dir).and_return(tests_dir)
    allow(TestSource).to receive(:custom_dir).and_return(Rails.root.join("tmp/sync_spec_custom"))
  end

  after { FileUtils.rm_rf(tests_dir) }

  describe ".sync_file" do
    it "creates TestMetadatum from yaml" do
      expect { YamlSyncService.sync_file(yaml_path.to_s) }
        .to change(TestMetadatum, :count).by(1)
    end

    it "creates Questions from yaml" do
      expect { YamlSyncService.sync_file(yaml_path.to_s) }
        .to change(Question, :count).by(1)
    end

    it "sets correct attributes on TestMetadatum" do
      YamlSyncService.sync_file(yaml_path.to_s)
      meta = TestMetadatum.find_by(slug: "test-quiz")
      expect(meta.title).to eq("Test Quiz")
      expect(meta.difficulty).to eq("beginner")
      expect(meta.questions_count).to eq(1)
      expect(meta.tag_list).to eq([ "rails", "ruby" ])
    end

    it "does not re-sync unchanged file" do
      YamlSyncService.sync_file(yaml_path.to_s)
      expect { YamlSyncService.sync_file(yaml_path.to_s) }
        .not_to change(TestMetadatum, :count)
    end
  end

  describe ".load_questions" do
    it "returns questions array for existing slug" do
      questions = YamlSyncService.load_questions("test-quiz")
      expect(questions.length).to eq(1)
      expect(questions.first["id"]).to eq("q1")
    end

    it "returns empty array for non-existent slug" do
      expect(YamlSyncService.load_questions("nonexistent")).to eq([])
    end
  end

  describe ".sync_all" do
    it "syncs all yml files in tests dir" do
      expect { YamlSyncService.sync_all }
        .to change(TestMetadatum, :count).by(1)
    end
  end
end
