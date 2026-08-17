require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }
  config.active_support.report_deprecations = false
  config.cache_store = :memory_store
  config.active_job.queue_adapter = :async
  config.i18n.fallbacks = true
end
