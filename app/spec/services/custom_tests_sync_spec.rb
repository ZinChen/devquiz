require 'rails_helper'

RSpec.describe "Синхронизация локальных тестов" do
  let(:repo_dir)   { Rails.root.join("tmp/custom_sync_repo") }
  let(:custom_dir) { Rails.root.join("tmp/custom_sync_custom") }

  before do
    FileUtils.mkdir_p(repo_dir)
    allow(TestSource).to receive(:repo_dir).and_return(repo_dir)
    allow(TestSource).to receive(:custom_dir).and_return(custom_dir)
  end

  after { FileUtils.rm_rf([ repo_dir, custom_dir ]) }

  def write_test(dir, slug, title:, question_text: "Вопрос?")
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, "#{slug}.yml"), {
      "slug" => slug, "title" => title,
      "questions" => [ {
        "id" => "q1", "text" => question_text, "type" => "single",
        "options" => [
          { "id" => "a", "text" => "Да",  "correct" => true },
          { "id" => "b", "text" => "Нет", "correct" => false }
        ]
      } ]
    }.to_yaml)
  end

  it "заводит тест из локальной папки с пометкой source=custom" do
    write_test(custom_dir, "my-local", title: "Мой тест")

    YamlSyncService.sync_all

    meta = TestMetadatum.find_by(slug: "my-local")
    expect(meta.title).to eq("Мой тест")
    expect(meta.source).to eq(TestSource::CUSTOM)
    expect(meta).to be_custom
    expect(meta.overrides_repo).to be false
  end

  it "помечает репозиторные тесты как source=repo" do
    write_test(repo_dir, "from-repo", title: "Репо")

    YamlSyncService.sync_all

    expect(TestMetadatum.find_by(slug: "from-repo").source).to eq(TestSource::REPO)
  end

  it "локальный файл подменяет репозиторный с тем же слагом" do
    write_test(repo_dir,   "dup", title: "Репозиторный", question_text: "Из репо?")
    write_test(custom_dir, "dup", title: "Локальный",    question_text: "Из локальной?")

    YamlSyncService.sync_all

    meta = TestMetadatum.find_by(slug: "dup")
    expect(meta.title).to eq("Локальный")
    expect(meta.overrides_repo).to be true
    # Заводится одна запись, а не две: слаг уникален.
    expect(TestMetadatum.where(slug: "dup").count).to eq(1)
  end

  it "отдаёт вопросы из подменяющего файла" do
    write_test(repo_dir,   "dup", title: "Р", question_text: "Из репо?")
    write_test(custom_dir, "dup", title: "Л", question_text: "Из локальной?")

    YamlSyncService.sync_all

    expect(YamlSyncService.load_questions("dup").first["text"]).to eq("Из локальной?")
  end

  it "переносит метку источника, когда файл переехал в локальную папку" do
    write_test(repo_dir, "moving", title: "Тест")
    YamlSyncService.sync_all
    expect(TestMetadatum.find_by(slug: "moving").source).to eq(TestSource::REPO)

    # Тот же самый файл, только в другой папке: контрольная сумма не изменилась.
    FileUtils.rm(File.join(repo_dir, "moving.yml"))
    write_test(custom_dir, "moving", title: "Тест")
    YamlSyncService.sync_all

    meta = TestMetadatum.find_by(slug: "moving")
    expect(meta.source).to eq(TestSource::CUSTOM)
    expect(meta.deleted_at).to be_nil
  end

  it "прячет локальный тест, если папка пропала, но не теряет попытки" do
    write_test(custom_dir, "vanishing", title: "Исчезающий")
    YamlSyncService.sync_all
    create(:test_attempt, test_slug: "vanishing")

    FileUtils.rm_rf(custom_dir)
    YamlSyncService.sync_all

    expect(TestMetadatum.find_by(slug: "vanishing").deleted_at).to be_present
    expect(TestMetadatum.active.where(slug: "vanishing")).to be_empty
    expect(TestAttempt.where(test_slug: "vanishing").count).to eq(1)
  end

  it "возвращает тест в список, когда папка вернулась" do
    write_test(custom_dir, "back", title: "Вернулся")
    YamlSyncService.sync_all
    FileUtils.rm_rf(custom_dir)
    YamlSyncService.sync_all

    write_test(custom_dir, "back", title: "Вернулся")
    YamlSyncService.sync_all

    expect(TestMetadatum.active.find_by(slug: "back")).to be_present
    # Вопросы тоже должны ожить, иначе тест откроется пустым.
    expect(Question.active.where(test_slug: "back").count).to eq(1)
  end

  it "работает, когда локальной папки нет вовсе" do
    write_test(repo_dir, "solo", title: "Один")

    expect { YamlSyncService.sync_all }.not_to raise_error
    expect(TestMetadatum.active.find_by(slug: "solo")).to be_present
  end
end
