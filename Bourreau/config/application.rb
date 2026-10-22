require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module CbrainRailsBourreau
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks generators])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")


    #### CBRAIN HERE ####

    # CBRAIN Plugins load paths: add directory for the CbrainTask models
    # This directory contains symbolic links to a special loader code
    # which will properly fetch the code in portal/xyz.rb or bourreau/xyz.rb
    # depending on the rails app currently executing.
    #
    # A rake task, cbrain:plugins:install:all, will create symlinks in there and
    # properly set up all tasks installed from plugins (and the defaults tasks).
    config.eager_load_paths += Dir[ "#{config.root}/cbrain_plugins/installed-plugins" ]

    # CBRAIN Plugins load paths: where userfiles defined by plugins are located (as links)
    config.eager_load_paths += Dir[ "#{config.root}/cbrain_plugins/installed-plugins/userfiles" ]

    # CBRAIN Plugins load paths: add lib directory for standalone Ruby files
    config.eager_load_paths += Dir[ "#{config.root}/cbrain_plugins/installed-plugins/lib" ]

    # CBRAIN Plugins: this folder contains support code and views that should not be loaded directly
    Rails.autoloaders.main.ignore(Rails.root.join("cbrain_plugins/installed-plugins/task_support_links"))

    # YAML serializer options
    config.active_record.default_column_serializer = YAML
    config.active_record.yaml_column_permitted_classes = [
      Symbol,
      Date,
      Time,
      ActiveSupport::HashWithIndifferentAccess,
      ActiveSupport::TimeZone,
      ActiveSupport::TimeWithZone,
      ActionController::Parameters,
      Set
    ]

    # Schedule the validation code to run after the application boots
    config.after_initialize do
      CbrainBootValidations.validate!
    end

    # Configure the CBRAIN console with all our helpers
    console do
      # This is a trick where we synthetically add the path to a irbrc-type file
      # as some command-line arguments.
      ARGV.push("-r","#{Rails.root}/config/console_rc/init_rc.rb")
    end

  end
end
