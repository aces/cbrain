# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
#
# CBRAIN project
#
# $Id$

# Superclass to all *BrainPortal* controllers. Contains
# helper methods for checking various aspects of the current
# session.
class ApplicationController < ActionController::Base

  
  Revision_info="$Id$"

  include AuthenticatedSystem
  include ExceptionLoggable

  helper_method :check_role, :not_admin_user, :current_session
  helper_method :available_data_providers, :available_bourreaux
  helper        :all # include all helpers, all the time

  filter_parameter_logging :password, :login, :email, :full_name, :role

  before_filter :set_cache_killer
  before_filter :prepare_messages
  before_filter :set_session, :only  => :index
  before_filter :password_reset
  around_filter :catch_cbrain_message
    
  # See ActionController::RequestForgeryProtection for details
  # Uncomment the :secret if you're not using the cookie session store
  protect_from_forgery :secret => 'b5e7873bd1bd67826a2661e01621334b'
  
  private
  
  def set_session
    current_session.update(params)
    @filter_params = current_session.params_for(params[:controller])
  end
  
  def password_reset
    if current_user && current_user.password_reset && params[:controller] != "sessions"
      unless params[:controller] == "users" && (params[:action] == "show" || params[:action] == "update")
        flash[:notice] = "Please reset your password."
        redirect_to user_path(current_user)
      end
    end
  end
  
  #Catch and display cbrain messages
  def catch_cbrain_message
    begin
      yield
    rescue ActiveRecord::RecordNotFound => e
      flash[:error] = "The record you requested does not exist."
      redirect_to default_redirect
    rescue CbrainException => cbm
      if cbm.is_a? CbrainNotice
         flash[:notice] = cbm.message    # + "\n" + cbm.backtrace[0..5].join("\n")
      else
         flash[:error]  = cbm.message    # + "\n" + cbm.backtrace[0..5].join("\n")
      end
      respond_to do |format|
        format.html { redirect_to cbm.redirect || default_redirect }
        format.js do
          render :update do |page|
            page.redirect_to cbm.redirect || default_redirect
          end
        end
        format.xml  { render :xml => {:error  => cbm.message}, :status => :unprocessable_entity }
      end
    rescue => e
      raise if ENV['RAILS_ENV'] == 'development' #Want to see stack trace in dev.
      
      Message.send_internal_error_message(current_user, "Exception Caught", e, params)
      log_exception(e)
      flash[:error] = "An error occurred. A message has been sent to the admins. Please try again later."
      redirect_to default_redirect
      return
    end
  end
  
  def prepare_messages

    if BrainPortal.current_resource.portal_locked?
      flash.now[:error] ||= ""
      flash.now[:error] += "\n" unless flash.now[:error].blank?
      flash.now[:error] += "This portal is currently locked."
    end
    
    return unless current_user
    
    @display_messages = []
    
    unread_messages = current_user.messages.all(:conditions  => { :read => false }, :order  => "last_sent DESC")
    @unread_message_count = unread_messages.size
    
    unread_messages.each do |mess|
      if mess.expiry.blank? || mess.expiry > Time.now
        if mess.critical? || mess.display?
          @display_messages << mess
          unless mess.critical?
            mess.update_attributes(:display  => false)
          end
        end
      else  
        mess.update_attributes(:read  => true)
      end
    end
  end
    
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
    result = current_user && user && (current_user == user || current_user.role == 'admin' || (current_user.has_role?(:site_manager) && current_user.site == user.site))
  end
  
  #Returns the current session as a Session object.
  def current_session
    @session ||= Session.new(session, params)
  end

  #Returns an array of the DataProvider objects representing the data providers that can be accessed by +user+.
  def available_data_providers(user = current_user)
    DataProvider.find(:all, :conditions => { :online => true, :read_only => false }).select { |p| p.can_be_accessed_by?(user) }
  end

  #Returns an array of the Bourreau objects representing the bourreaux that can be accessed by +user+.
  def available_bourreaux(user = current_user)
    Bourreau.find(:all, :conditions => { :online => true  }).select { |p| p.can_be_accessed_by?(user) }
  end
  
  #Helper method to render and error page. Will render public/<+status+>.html
  def access_error(status)
      render(:file => (RAILS_ROOT + '/public/' + status.to_s + '.html'), :status  => status)
  end
  
  def default_redirect
    if self.respond_to?(:index) && params[:action] != "index"
      {:action => :index}
    else
      home_path
    end
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

#Patch: Load all models so single-table inheritance works properly.
begin
  Dir.chdir(File.join(RAILS_ROOT, "app", "models")) do
    Dir.glob("*.rb").each do |model|
      model.sub!(/.rb$/,"")
      require_dependency "#{model}.rb" unless Object.const_defined? model.classify
    end
  end
  Dir.chdir(File.join(RAILS_ROOT, "app", "models", "cbrain_task")) do
    Dir.glob("*.rb").each do |model|
      model.sub!(/.rb$/,"")
      require_dependency "cbrain_task/#{model}.rb" unless CbrainTask.const_defined? model.classify
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

LoggedExceptionsController.class_eval do
  # set the same session key as the app
  session :session_key => '_BrainPortal2_session'
  
  include AuthenticatedSystem
  protect_from_forgery :secret => 'b5e7873bd1bd67826a2661e01621334b'

  before_filter :login_required, :admin_role_required

  # optional, sets the application name for the rss feeds
  self.application_name = "BrainPortal"
end
