# frozen_string_literal: true

require_relative 'boot'

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
# require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "action_cable/engine"
require "sprockets/railtie"
require "rails/test_unit/railtie"
# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, :staging, or :production.
Bundler.require(*Rails.groups)

module GitConflictDetector
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    config.time_zone = Time.zone = 'Pacific Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    config.eager_load_paths += Dir["#{config.root}/lib/**/"]

    config.exceptions_app = routes

    config.after_initialize do
      # TODO: Cleanup the creation of the GlobalSettings global variable
      # It currently relies on this line being the first time the application references it
      # Earlier references could cause the validation to fail because the ENV is not loaded yet
      Rails.application.routes.default_url_options[:host] = GlobalSettings.web_server_url

      # disable logging of SQL statements
      ActiveRecord::Base.logger = nil

      # make the cache folder
      FileUtils.mkdir_p(GlobalSettings.cache_directory)
    end

    config.active_job.queue_adapter = :delayed_job

    initializer :configure_secrets, before: :load_environment_config, after: :load_custom_logging, group: :all do
      require 'invoca_secrets'
      require_relative 'secrets_config'
    end

    initializer :configure_mailer, after: [:configure_secrets, :load_environment_config], group: :all do
      smtp_settings = InvocaSecrets['email', 'send_grid', 'invoca_net', 'smtp'].symbolize_keys
      config.action_mailer.smtp_settings = smtp_settings
      Mail.defaults { delivery_method :smtp, smtp_settings }
      ActionMailer::Base.smtp_settings = smtp_settings
    end
  end
end
