CbrainRailsPortal::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # In the development environment your application's code is reloaded on
  # every request.  This slows down response time but is perfect for development
  # since you don't have to restart the webserver when you make code changes.
  config.cache_classes = false

  # Log error messages when you accidentally call methods on nil.
  config.whiny_nils = true

  # Show full error reports and disable caching
  config.consider_all_requests_local       = true
  config.action_view.debug_rjs             = true
  config.action_controller.perform_caching = false

  # Don't care if the mailer can't send
  config.action_mailer.raise_delivery_errors = false

  # Print deprecation notices to the Rails logger
  config.active_support.deprecation = :log

  # Only use best-standards-support built into browsers
  config.action_dispatch.best_standards_support = :builtin
end


CbrainRailsPortal::Application.config.after_initialize do

  LoggedExceptionsController.class_eval do
    # set the same session key as the app
    #session :session_key => CbrainRailsPortal::Application.config.secret_token

    include AuthenticatedSystem

    protect_from_forgery :secret => CbrainRailsPortal::Application.config.secret_token

    before_filter :login_required, :admin_role_required

    # optional, sets the application name for the rss feeds
    self.application_name = "BrainPortal"
  end

end
