namespace :yaml_sync do
  def report_sources
    TestSource.dirs.each do |dir|
      count = Dir.glob(File.join(dir.to_s, "*.yml")).count
      puts "YamlSyncService: #{TestSource.source_of(dir)} dir=#{dir} files=#{count}"
    end
    puts "YamlSyncService: tests_custom/ отсутствует — только репозиторные тесты" unless TestSource.custom_dir?

    overridden = TestSource.files_by_slug.select { |_, e| e[:overrides_repo] }.keys
    puts "YamlSyncService: подменены локальными файлами: #{overridden.join(', ')}" if overridden.any?
  end

  desc "Sync all YAML test files to database"
  task sync_all: :environment do
    report_sources
    YamlSyncService.sync_all
    puts "YamlSyncService: sync complete"
  end

  desc "Force re-sync all YAML test files (ignores checksum cache)"
  task force_sync: :environment do
    puts "YamlSyncService: resetting checksums..."
    TestMetadatum.update_all(file_checksum: nil)
    report_sources
    YamlSyncService.sync_all
    puts "YamlSyncService: force sync complete"
  end
end
