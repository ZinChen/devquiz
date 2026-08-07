require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Behind a TLS-terminating proxy (Caddy), requests reach Rails over plain HTTP.
  # Without assume_ssl, force_ssl would redirect them back to https and loop forever.
  config.assume_ssl = ENV["ASSUME_SSL"] == "true"
  config.force_ssl = ENV.fetch("FORCE_SSL", "true") == "true"

  config.log_tags  = [ :request_id ]
  config.logger    = ActiveSupport::TaggedLogging.logger(STDOUT)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")
  config.silence_healthcheck_path = "/up"

  config.active_support.report_deprecations = false
  config.cache_store = :memory_store
  config.active_record.dump_schema_after_migration = false
  config.active_record.attributes_for_inspect = [ :id ]
end
