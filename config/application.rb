# frozen_string_literal: true

require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
# ActiveRecord omitido de propósito — store = Mongoid (ver README).
require "action_controller/railtie"
require "action_view/railtie"

Bundler.require(*Rails.groups)

module PreferencesApiMongo
  class Application < Rails::Application
    config.load_defaults 8.0
    config.autoload_lib(ignore: %w[assets tasks])
    config.api_only = true
  end
end
