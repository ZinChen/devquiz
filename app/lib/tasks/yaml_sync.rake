namespace :yaml_sync do
  desc "Sync all YAML test files to database"
  task sync_all: :environment do
    puts "YamlSyncService: TESTS_DIR=#{YamlSyncService::TESTS_DIR}"
    puts "YamlSyncService: files found=#{Dir.glob(YamlSyncService::TESTS_DIR.join('*.yml')).count}"
    YamlSyncService.sync_all
    puts "YamlSyncService: sync complete"
  end
end
