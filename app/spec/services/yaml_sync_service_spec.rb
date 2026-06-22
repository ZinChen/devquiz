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

  let(:yaml_path) { Rails.root.join("tmp/test-quiz.yml") }

  before do
    File.write(yaml_path, yaml_content.to_yaml)
    stub_const("YamlSyncService::TESTS_DIR", Rails.root.join("tmp"))
  end

  after { File.delete(yaml_path) if File.exist?(yaml_path) }

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
