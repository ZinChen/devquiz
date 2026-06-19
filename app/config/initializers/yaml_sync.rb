Rails.application.config.after_initialize do
  YamlSyncService.sync_all if ActiveRecord::Base.connection.table_exists?("test_metadata")
rescue ActiveRecord::NoDatabaseError, PG::ConnectionBad
  Rails.logger.warn "YamlSyncService: database not available on boot, skipping sync"
end
