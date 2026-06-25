namespace :yaml_sync do
  desc "Sync all YAML test files to database"
  task sync_all: :environment do
    puts "YamlSyncService: TESTS_DIR=#{YamlSyncService::TESTS_DIR}"
    puts "YamlSyncService: files found=#{Dir.glob(YamlSyncService::TESTS_DIR.join('*.yml')).count}"
    YamlSyncService.sync_all
    puts "YamlSyncService: sync complete"
  end

  desc "Force re-sync all YAML test files (ignores checksum cache)"
  task force_sync: :environment do
    puts "YamlSyncService: resetting checksums..."
    TestMetadatum.update_all(file_checksum: nil)
    puts "YamlSyncService: TESTS_DIR=#{YamlSyncService::TESTS_DIR}"
    puts "YamlSyncService: files found=#{Dir.glob(YamlSyncService::TESTS_DIR.join('*.yml')).count}"
    YamlSyncService.sync_all
    puts "YamlSyncService: force sync complete"
  end
end
