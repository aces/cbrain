# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
#
# CBRAIN project
#
# $Id$

#Patch: Load all models so single-table inheritance works properly.
begin
  Dir.chdir(File.join(RAILS_ROOT, "app", "models")) do
    Dir.glob("*.rb").each do |model|
      require_dependency model unless Object.const_defined? model.split(".")[0].classify
    end
  end
rescue => error
  if error.to_s.match(/Mysql::Error.*Table.*doesn't exist/i)
    puts "Skipping model load:\n\t- Database table doesn't exist yet. It's likely this system is new and the migrations have not been run yet."
  elsif error.to_s.match(/Unknown database/i)
    puts "Skipping model load:\n\t- System database doesn't exist yet. It's likely this system is new and the migrations have not been run yet."
  else
    raise
  end
end

# Superclass to all *BrainPortal* controllers. Contains
# helper methods for checking various aspects of the current
# session.
class ApplicationController < ActionController::Base

  Revision_info="$Id$"

  include AuthenticatedSystem
  include ExceptionLoggable

  helper_method :check_role, :not_admin_user, :current_session
  helper_method :available_data_providers, :available_bourreaux
  helper :all # include all helpers, all the time
  filter_parameter_logging :password, :login, :email, :full_name, :role

  before_filter :set_cache_killer
    
  # See ActionController::RequestForgeryProtection for details
  # Uncomment the :secret if you're not using the cookie session store
  protect_from_forgery :secret => 'b5e7873bd1bd67826a2661e01621334b'
  
  private
    
  #Checks that the current user's role matches +role+.
  def check_role(role)
    current_user && current_user.role.to_sym == role.to_sym
  end
  
  #Checks that the current user is not the default *admin* user.
  def not_admin_user(user)
    user && user.login != 'admin'
  end
  
  #Checks that the current user is the same as +user+. Used to ensure permission
  #for changing account information.
  def edit_permission?(user)
    current_user && user && (current_user == user || current_user.role == 'admin')
  end
  
  #Returns the current session as a Session object.
  def current_session
    @session ||= Session.new(session)
  end

  #Returns an array of the DataProvider objects representing the data providers that can be accessed by +user+.
  def available_data_providers(user)
    DataProvider.find(:all, :conditions => { :online => true, :read_only => false }).select { |p| p.can_be_accessed_by(user) }
  end

  #Returns an array of the Bourreau objects representing the bourreaux that can be accessed by +user+.
  def available_bourreaux(user)
    Bourreau.find(:all, :conditions => { :online => true  }).select { |p| p.can_be_accessed_by(user) }
  end
  
  #Prevents pages from being cached in the browser. 
  #This prevents users from being able to access pages after logout by hitting
  #the 'back' button on the browser.
  #
  #NOTE: Does not seem to be effective for all browsers.
  def set_cache_killer
     # (no-cache) Instructs the browser not to cache and get a fresh version of the resource
     # (no-store) Makes sure the resource is not stored to disk anywhere - does not guarantee that the 
     # resource will not be written
     # (must-revalidate) the cache may use the response in replying to a subsequent reques but if the resonse is stale
     # all caches must first revalidate with the origin server using the request headers from the new request to allow
     # the origin server to authenticate the new reques
     # (max-age) Indicates that the client is willing to accept a response whose age is no greater than the specified time in seconds. 
     # Unless max- stale directive is also included, the client is not willing to accept a stale response.
     #response.headers["Cache-Control"] = "no-cache, no-store, max-age=0, must-revalidate"
     response.headers["Last-Modified"] = Time.now.httpdate
     response.headers["Expires"] = "#{1.year.ago}"
     # HTTP 1.0
     # When the no-cache directive is present in a request message, an application SHOULD forward the request 
     # toward the origin server even if it has a cached copy of what is being requested
     response.headers["Pragma"] = "no-cache"
     # HTTP 1.1 'pre-check=0, post-check=0' (IE specific)
     response.headers["Cache-Control"] = 'no-store, no-cache, must-revalidate, max-age=0, pre-check=0, post-check=0'
   end

end

LoggedExceptionsController.class_eval do
  # set the same session key as the app
  session :session_key => '_BrainPortal2_session'
  
  include AuthenticatedSystem
  protect_from_forgery :secret => 'b5e7873bd1bd67826a2661e01621334b'

  before_filter :login_required, :admin_role_required

  # optional, sets the application name for the rss feeds
  self.application_name = "BrainPortal"
end
