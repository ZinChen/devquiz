Rails.application.config.after_initialize do
  begin
    YamlSyncService.sync_all if ActiveRecord::Base.connection.table_exists?("test_metadata")
  rescue ActiveRecord::NoDatabaseError,
         ActiveRecord::ConnectionNotEstablished,
         PG::ConnectionBad,
         PG::Error => e
    Rails.logger.warn "YamlSyncService: database not available on boot (#{e.class}), skipping sync"
  end
end
