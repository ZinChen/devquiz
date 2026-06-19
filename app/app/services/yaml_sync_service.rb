require "digest"
require "yaml"

class YamlSyncService
  TESTS_DIR = Rails.root.join("../tests").expand_path

  def self.sync_all
    Dir.glob(TESTS_DIR.join("*.yml")).each do |path|
      sync_file(path)
    rescue => e
      Rails.logger.error "YamlSyncService: failed to sync #{path}: #{e.message}"
    end
  end

  def self.load_questions(slug)
    path = TESTS_DIR.join("#{slug}.yml")
    return [] unless File.exist?(path)
    data = YAML.safe_load(File.read(path), permitted_classes: [Symbol])
    data["questions"] || []
  end

  def self.sync_file(path)
    content  = File.read(path)
    checksum = Digest::MD5.hexdigest(content)
    data     = YAML.safe_load(content, permitted_classes: [Symbol])
    slug     = data["slug"]

    return unless slug.present?

    meta = TestMetadatum.find_or_initialize_by(slug: slug)
    return if meta.persisted? && meta.file_checksum == checksum

    meta.assign_attributes(
      title:           data["title"],
      description:     data["description"],
      difficulty:      data["difficulty"],
      estimated_time:  data["estimated_time"],
      questions_count: Array(data["questions"]).size,
      file_checksum:   checksum,
      synced_at:       Time.current
    )
    meta.tag_list = Array(data["tags"])
    meta.save!
  end
end
