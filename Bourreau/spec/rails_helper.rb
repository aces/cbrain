
# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV['RAILS_ENV'] ||= 'test'

# A Bourreau Rails application normally doesn't have a database.yml file;
# so in order to connect to the database we parse the content of the
# BrainPortal's side's database.yml and re-encode its connection
# information into a DATABASE_URL environment variable:
#
# DATABASE_URL=adapter://user:password@host/dbname
#
# e.g.
# DATABASE_URL=mysql2://prioux:mypassword@localhost/prioux_test
#
require 'yaml'
1.times do # a block to encapsulate local variables and not polute anything
  env           = ENV['RAILS_ENV']
  dbconfig_file = "../BrainPortal/config/database.yml"
  dbinfo        = YAML.load_file dbconfig_file
  config        = dbinfo[env]
  raise "Can't find entry for Rails environment '#{env}' in file #{dbconfig_file}..." unless config
  adapter       = config["adapter"]  || "noadapter"
  username      = config["username"] || "nousername"
  password      = config["password"]
  host          = config["host"]     || "localhost"
  database      = config["database"] || "nodatabase"
  password    &&= ":#{password}"
  url           = "#{adapter}://#{username}#{password}@#{host}/#{database}"
  ENV["DATABASE_URL"] = URI.escape url
  ENV["CBRAIN_RAILS_APP_NAME"] = "Test_Bourreau_Exec" # This is initialized by rake db:seed:test:bourreau
end

require 'spec_helper'
require File.expand_path('../../config/environment', __FILE__)
require 'rspec/rails'
# Add additional requires below this line. Rails is not loaded until this point!

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.
#
# Dir[Rails.root.join('spec/support/**/*.rb')].each { |f| require f }

# Preload two important exception classes
CbrainError ; CbrainNotice

RSpec.configure do |config|
  # If you do not include FactoryBot::Syntax::Methods in your test suite,
  # then all factory_girl methods will need to be prefaced with FactoryBot.
  config.include FactoryBot::Syntax::Methods

  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  # RSpec Rails can automatically mix in different behaviours to your tests
  # based on their file location, for example enabling you to call `get` and
  # `post` in specs under `spec/controllers`.
  #
  # You can disable this behaviour by removing the line below, and instead
  # explicitly tag your specs with their type, e.g.:
  #
  #     RSpec.describe UsersController, :type => :controller do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://relishapp.com/rspec/rspec-rails/docs
  config.infer_spec_type_from_file_location!
end
