
#
# CBRAIN Project
#
# Copyright (C) 2008-2012
# The Royal Institution for the Advancement of Learning
# McGill University
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.  
#

require File.expand_path('../boot', __FILE__)

require 'rails/all'

# If you have a Gemfile, require the gems listed there, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(:default, Rails.env) if defined?(Bundler)

module CbrainRailsBourreau
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Custom directories with classes and modules you want to be autoloadable.
    # config.autoload_paths += %W(#{config.root}/extras)
    config.autoload_paths += Dir["#{config.root}/lib"]
    config.autoload_paths += Dir["#{config.root}/lib/cbrain_task_generators"]

    # CBRAIN Plugins load paths: add directories for each Userfile model
    config.autoload_paths += Dir[ * Dir.glob("#{config.root}/cbrain_plugins/installed-plugins/userfiles/*") ]

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

    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named.
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

    # Activate observers that should always be running.
    # config.active_record.observers = :cacher, :garbage_collector, :forum_observer

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # JavaScript files you want as :defaults (application.js is always included).
    # config.action_view.javascript_expansions[:defaults] = %w(jquery rails)

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = "utf-8"

    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [:password, :login, :email, :full_name, :role ]
  end
end
