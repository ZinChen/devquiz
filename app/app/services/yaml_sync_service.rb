require "digest"
require "yaml"

class YamlSyncService
  TESTS_DIR = Rails.root.join("../tests").expand_path

  def self.sync_all
    file_slugs = Dir.glob(TESTS_DIR.join("*.yml")).filter_map do |path|
      sync_file(path)
    rescue => e
      Rails.logger.error "YamlSyncService: failed to sync #{path}: #{e.message}"
      nil
    end

    soft_delete_missing(file_slugs.compact)
  end

  def self.load_questions(slug)
    path = TESTS_DIR.join("#{slug}.yml")
    return [] unless File.exist?(path)
    data = YAML.safe_load(File.read(path), permitted_classes: [ Symbol ])
    data["questions"] || []
  end

  def self.sync_file(path)
    content  = File.read(path)
    checksum = Digest::MD5.hexdigest(content)
    data     = YAML.safe_load(content, permitted_classes: [ Symbol ])
    slug     = data["slug"]

    return unless slug.present?

    meta = TestMetadatum.find_or_initialize_by(slug: slug)

    unless meta.persisted? && meta.file_checksum == checksum
      meta.assign_attributes(
        title:           data["title"],
        description:     data["description"],
        difficulty:      data["difficulty"],
        estimated_time:  data["estimated_time"],
        questions_count: Array(data["questions"]).size,
        file_checksum:   checksum,
        deleted_at:      nil,
        synced_at:       Time.current
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
          recommendation:       q["recommendation"].to_s.presence
        )
        rec.save!
      end
    end
  end
end
