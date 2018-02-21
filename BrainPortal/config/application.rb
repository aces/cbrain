require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module CbrainRailsPortal
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Custom directories with classes and modules you want to be autoloadable.
    # config.autoload_paths += %W(#{config.root}/extras)
    config.eager_load_paths += Dir["#{config.root}/lib"]
    config.eager_load_paths += Dir["#{config.root}/lib/cbrain_task_generators"]

    # CBRAIN Plugins load paths: add directories for each Userfile model
    config.eager_load_paths += Dir[ * Dir.glob("#{config.root}/cbrain_plugins/installed-plugins/userfiles/*") ]

    # CBRAIN Plugins load paths: add lib directory for standalone Ruby files
    config.eager_load_paths += Dir["#{config.root}/cbrain_plugins/installed-plugins/lib"]

    # CBRAIN Plugins load paths: add directory for the CbrainTask models
    # This directory contains symbolic links to a special loader code
    # which will properly fetch the code in portal/xyz.rb or bourreau/xyz.rb
    # depending on the rails app currently executing.
    #
    # A rake task, cbrain:plugins:install:all, will create symlinks in there and
    # properly set up all tasks installed from plugins (and the defaults tasks).
    config.autoload_paths += Dir["#{config.root}/cbrain_plugins/installed-plugins/cbrain_task"]

    # CBRAIN Plugins load paths: add directory for descriptor-based CbrainTask
    # models. This directory, similarly to the one above, contains symbolic
    # links to a special loader code which will call a task generator to
    # generate the requested CbrainTask subclass on the fly.
    #
    # The rake task cbrain:plugins:install:all also takes care of creating the
    # symlinks for this location.
    config.autoload_paths += Dir["#{config.root}/cbrain_plugins/installed-plugins/cbrain_task_descriptors"]

    config.action_controller.include_all_helpers = true

  end
end
