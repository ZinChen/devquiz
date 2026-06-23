namespace :yaml_sync do
  desc "Sync all YAML test files to database"
  task sync_all: :environment do
    YamlSyncService.sync_all
    puts "YamlSyncService: sync complete"
  end
end
