require 'rails_helper'

RSpec.describe TestSource do
  let(:repo_dir)   { Rails.root.join("tmp/source_spec_repo") }
  let(:custom_dir) { Rails.root.join("tmp/source_spec_custom") }

  before do
    FileUtils.mkdir_p(repo_dir)
    allow(described_class).to receive(:repo_dir).and_return(repo_dir)
    allow(described_class).to receive(:custom_dir).and_return(custom_dir)
  end

  after { FileUtils.rm_rf([ repo_dir, custom_dir ]) }

  def write(dir, slug, body = "title: T\n")
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, "#{slug}.yml"), body)
  end

  describe ".dirs" do
    it "не включает несуществующую папку с локальными тестами" do
      expect(described_class.dirs).to eq([ repo_dir ])
    end

    it "включает обе папки, когда локальная существует" do
      FileUtils.mkdir_p(custom_dir)
      expect(described_class.dirs).to eq([ repo_dir, custom_dir ])
    end
  end

  describe ".files_by_slug" do
    it "находит тесты из обеих папок" do
      write(repo_dir, "from-repo")
      write(custom_dir, "from-custom")

      expect(described_class.files_by_slug.keys).to contain_exactly("from-repo", "from-custom")
    end

    it "помечает источник каждого файла" do
      write(repo_dir, "a")
      write(custom_dir, "b")

      entries = described_class.files_by_slug
      expect(entries["a"][:source]).to eq(described_class::REPO)
      expect(entries["b"][:source]).to eq(described_class::CUSTOM)
    end

    it "при совпадении слагов побеждает локальный файл" do
      write(repo_dir,   "dup", "title: Репозиторный\n")
      write(custom_dir, "dup", "title: Локальный\n")

      entry = described_class.files_by_slug["dup"]

      expect(entry[:source]).to eq(described_class::CUSTOM)
      expect(entry[:overrides_repo]).to be true
      expect(File.read(entry[:path])).to include("Локальный")
    end

    it "не помечает подменой локальный тест с уникальным слагом" do
      write(custom_dir, "only-custom")

      expect(described_class.files_by_slug["only-custom"][:overrides_repo]).to be false
    end

    it "пропускает topics.yml — это словарь тем, а не тест" do
      write(repo_dir, "topics")

      expect(described_class.files_by_slug).not_to have_key("topics")
    end
  end

  describe ".path_for" do
    it "возвращает путь к файлу по слагу" do
      write(repo_dir, "known")

      expect(described_class.path_for("known")).to end_with("known.yml")
    end

    it "возвращает nil для неизвестного слага" do
      expect(described_class.path_for("нет-такого")).to be_nil
    end
  end
end
