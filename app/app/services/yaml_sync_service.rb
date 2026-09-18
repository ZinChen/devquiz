require "digest"
require "yaml"

class YamlSyncService
  # Папка с тестами из репозитория. Оставлена как есть: по ней лежит topics.yml,
  # и это по-прежнему «основной» каталог. Про вторую папку знает TestSource.
  TESTS_DIR = Rails.root.join("../tests").expand_path

  def self.sync_all
    entries = TestSource.files_by_slug

    file_slugs = entries.filter_map do |_slug, entry|
      sync_file(entry[:path], source: entry[:source], overrides_repo: entry[:overrides_repo])
    rescue => e
      Rails.logger.error "YamlSyncService: failed to sync #{entry[:path]}: #{e.message}"
      nil
    end

    soft_delete_missing(file_slugs.compact)
  end

  def self.load_questions(slug)
    path = TestSource.path_for(slug)
    return [] unless path && File.exist?(path)
    data = YAML.safe_load(File.read(path), permitted_classes: [ Symbol ])
    data["questions"] || []
  end

  # Шапка теста (language, default_challenge_mode и прочее вне questions).
  # Пустой хэш, если файла нет или он не читается: вызывающему нужны дефолты,
  # а не исключение.
  def self.load_meta(slug)
    path = TestSource.path_for(slug)
    return {} unless path && File.exist?(path)

    data = YAML.safe_load(File.read(path), permitted_classes: [ Symbol ])
    data.is_a?(Hash) ? data : {}
  rescue StandardError
    {}
  end

  def self.sync_file(path, source: nil, overrides_repo: false)
    content  = File.read(path)
    checksum = Digest::MD5.hexdigest(content)
    data     = YAML.safe_load(content, permitted_classes: [ Symbol ])
    slug     = data["slug"]

    return unless slug.present?

    # Вопросы потом ищутся по имени файла (TestSource.path_for), а метаданные
    # пишутся под slug из yaml. Разойдись они — тест открывался бы пустым,
    # поэтому имя файла считаем главным и говорим об этом вслух.
    file_slug = File.basename(path, ".yml")
    if slug != file_slug
      Rails.logger.warn "YamlSyncService: #{path} declares slug=#{slug}, using file name #{file_slug}"
      slug = file_slug
    end

    source ||= TestSource.source_of(File.dirname(path))

    meta = TestMetadatum.find_or_initialize_by(slug: slug)

    # Пересобираем и когда файл не менялся, но переехал между папками (иначе
    # метка источника осталась бы от прошлого места) или когда запись была
    # мягко удалена — вернувшийся файл должен вернуть тест в список.
    unchanged = meta.persisted? && meta.file_checksum == checksum &&
                meta.source == source && meta.overrides_repo == overrides_repo &&
                meta.deleted_at.nil?

    unless unchanged
      has_code = Array(data["questions"]).any? { |q| q["type"] == "code_challenge" }
      meta.assign_attributes(
        title:             data["title"],
        description:       data["description"],
        difficulty:        data["difficulty"],
        estimated_time:    data["estimated_time"],
        questions_count:   Array(data["questions"]).size,
        has_code_challenge: has_code,
        file_checksum:     checksum,
        source:            source,
        overrides_repo:    overrides_repo,
        deleted_at:        nil,
        synced_at:         Time.current
      )
      meta.tag_list = Array(data["tags"])
      meta.save!

      sync_questions(slug, Array(data["questions"]))
    end

    slug
  end

  def self.soft_delete_missing(file_slugs)
    TestMetadatum.where.not(slug: file_slugs).where(deleted_at: nil).find_each do |meta|
      meta.soft_delete!
      Question.where(test_slug: meta.slug).where(deleted_at: nil).update_all(deleted_at: Time.current)
      Rails.logger.info "YamlSyncService: soft-deleted test #{meta.slug} (no yml file)"
    end
  end

  def self.sync_questions(slug, questions_data)
    questions_data.each do |q|
      qid = q["id"].to_s
      next if qid.blank?

      correct_ids = q["options"].to_a.select { |o| o["correct"] }.map { |o| o["id"].to_s }

      Question.find_or_initialize_by(test_slug: slug, question_id: qid).tap do |rec|
        rec.assign_attributes(
          text:                 q["text"].to_s,
          type_field:           q["type"].to_s.presence || "single",
          options:              q["options"].to_a.map { |o|
                                  opt = { "id" => o["id"].to_s, "text" => o["text"].to_s }
                                  opt["explanation"] = o["explanation"].to_s if o["explanation"].present?
                                  opt
                                },
          correct_ids:          correct_ids,
          explanation:          q["explanation"].to_s.presence,
          extended_explanation: q["extended_explanation"].to_s.presence,
          recommendation:       q["recommendation"].to_s.presence,
          # Вопрос мог быть мягко удалён вместе с тестом (soft_delete_missing).
          # Файл вернулся — значит, вопрос снова актуален, иначе тест открылся
          # бы пустым: закладки и слабые темы смотрят на active.
          deleted_at:           nil
        )
        rec.save!
      end
    end
  end
end
