
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

# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

require 'authenticated_system'

# Superclass to all *BrainPortal* controllers. Contains
# helper methods for checking various aspects of the current
# session.
class ApplicationController < ActionController::Base

  Revision_info=CbrainFileRevision[__FILE__]

  include AuthenticatedSystem
  include ExceptionLogger::ExceptionLoggable
  include BasicFilterHelpers
  include ViewHelpers
  include ApiHelpers
  include PermissionHelpers
  
  rescue_from Exception, :with => :log_exception_handler

  helper        :all # include all helpers, all the time

  before_filter :always_activate_session
  before_filter :set_cache_killer
  before_filter :prepare_messages
  before_filter :check_account_validity
  before_filter :adjust_system_time_zone
  around_filter :handle_cbrain_errors, :activate_user_time_zone
    
  # See ActionController::RequestForgeryProtection for details
  # Uncomment the :secret if you're not using the cookie session store
  protect_from_forgery :secret => 'b5e7873bd1bd67826a2661e01621334b'
  
  

  ########################################################################
  # Controller Filters
  ########################################################################

  private
  
  # Returns the name of the model class associated with a given contoller. By default
  # takes the name from the name of the controller, but can be redefined in subclasses
  # as needed.
  def resource_class
    @resource_class ||= Class.const_get self.class.to_s.sub(/Controller$/, "").singularize
  end

  # This method adjust the Rails app's time zone in the rare
  # cases where the admin has changed it in the DB using the
  # interface.
  def adjust_system_time_zone
    myself = RemoteResource.current_resource
    syszone = myself.time_zone
    return true unless syszone && ActiveSupport::TimeZone[syszone]
    if Time.zone.blank? || Time.zone.name != syszone
      #puts "\e[1;33;41mRESETTING TIME ZONE FROM '#{Time.zone.name rescue "unset"}' to '#{syszone}'.\e[0m"
      Time.zone = ActiveSupport::TimeZone[syszone]
      CbrainRailsPortal::Application.config.time_zone = syszone
      #Rails::Initializer.new(Rails.configuration).initialize_time_zone
    #else
    #  testtime = Userfile.first.created_at
    #  puts "\e[1;33;41mTIME ZONE STAYS SAME: #{syszone} TEST: #{testtime}\e[0m"
    end
    true
  end

  # This method wraps ALL other controller methods
  # into a sandbox where the value for Time.zone is
  # temporarily switched to the current user's time zone,
  # if it is defined. Otherwise, the Rails application's
  # time zone is used.
  def activate_user_time_zone #:nodoc:
    return yield unless current_user # nothing to do if no user logged in
    userzone = current_user.time_zone
    return yield unless userzone && ActiveSupport::TimeZone[userzone] # nothing to do if no user zone or zone is incorrect
    return yield if Time.zone && Time.zone.name == userzone # nothing to do if user's zone is same as system's
    Time.use_zone(ActiveSupport::TimeZone[userzone]) do
      yield
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
  
  # Check if the user needs to change their password
  # or sign license agreements.
  def check_account_validity
    return true unless current_user
    return true if params[:controller] == "sessions"

    #Check if license agreement have been signed
    unsigned_agreements = current_user.unsigned_license_agreements

    unless unsigned_agreements.empty?
      return true if params[:controller] == "portal" && params[:action] =~ /license$/
      return true if current_user.has_role?(:admin) && params[:controller] == "bourreaux"
      if File.exists?(Rails.root + "public/licenses/#{unsigned_agreements.first}.html")
        redirect_to :controller => :portal, :action => :show_license, :license => unsigned_agreements.first
      elsif current_user.has_role?(:admin)
        flash[:error] =  "License agreement '#{unsigned_agreements.first}' doesn't seem to exist.\n"
        flash[:error] += "Please place the license file in /public/licenses or remove it from below."
        redirect_to bourreau_path(RemoteResource.current_resource)
      end
    end
    #Check if passwords been reset.
    if current_user.password_reset
      unless params[:controller] == "users" && (params[:action] == "show" || params[:action] == "update")
        flash[:notice] = "Please reset your password."
        redirect_to user_path(current_user)
      end
    end
  end


  
  ########################################################################
  # CBRAIN Exception Handling (Filters)
  ########################################################################

  #Handle common exceptions
  def handle_cbrain_errors
    begin
      yield # try to execute the controller/action stuff

    # Record not accessible
    rescue ActiveRecord::RecordNotFound => e
      raise if Rails.env == 'development' #Want to see stack trace in dev.
      flash[:error] = "The object you requested does not exist or is not accessible to you."
      respond_to do |format|
        format.html { redirect_to default_redirect }
        format.js   { render :partial  => "shared/flash_update", :status  => 404 } 
        format.xml  { render :xml => {:error  => e.message}, :status => 404 }
      end

    # Action not accessible
    rescue ActionController::UnknownAction => e
      raise if Rails.env == 'development' #Want to see stack trace in dev.
      flash[:error] = "The page you requested does not exist."
      respond_to do |format|
        format.html { redirect_to default_redirect }
        format.js   { render :partial  => "shared/flash_update", :status  => 400 } 
        format.xml  { render :xml => {:error  => e.message}, :status => 400 }
      end

    # Internal CBRAIN errors
    rescue CbrainException => cbm
      if cbm.is_a? CbrainNotice
         flash[:notice] = cbm.message    # + "\n" + cbm.backtrace[0..5].join("\n")
      else
         flash[:error]  = cbm.message    # + "\n" + cbm.backtrace[0..5].join("\n")
      end
      logger.error "CbrainException for controller #{params[:controller]}, action #{params[:action]}: #{cbm.class} #{cbm.message}"
      respond_to do |format|
        format.html { redirect_to cbm.redirect || default_redirect }
        format.js   { render :partial  => "shared/flash_update", :status  => cbm.status } 
        format.xml  { render :xml => {:error  => cbm.message}, :status => cbm.status }
      end

    # Anything else is serious
    rescue => ex
      raise unless Rails.env == 'production' #Want to see stack trace in dev. Also will log it in exception logger

      # Note that send_internal_error_message will also censure :password from the params hash
      Message.send_internal_error_message(current_user, "Exception Caught", ex, params) rescue true
      log_exception(ex) # explicit logging in exception logger, since we won't re-raise it now.
      flash[:error] = "An error occurred. A message has been sent to the admins. Please try again later."
      logger.error "Exception for controller #{params[:controller]}, action #{params[:action]}: #{ex.class} #{ex.message}"
      respond_to do |format|
        format.html { redirect_to default_redirect }
        format.js   { render :partial  => "shared/flash_update", :status  => 500 } 
        format.xml  { render :xml => {:error  => e.message}, :status => 500 }
      end

    end

  end
  
  # Redirect to the index page if available and wasn't the source of
  # the exception, otherwise to welcome page.
  def default_redirect
    final_resting_place = { :controller => "portal", :action => "welcome" }
    if self.respond_to?(:index) && params[:action] != "index"
      { :action => :index }
    elsif final_resting_place.keys.all? { |k| params[k] == final_resting_place[k] }
      "/500.html" # in case there's an error in the welcome page itself
    else
      url_for(final_resting_place)
    end
  end
  
  ########################################################################
  # CBRAIN Messaging System Filters
  ########################################################################
    
  # Find new messages to be displayed at the top of the page.
  def prepare_messages
    return unless current_user
    return if     request.format.blank?
    return unless request.format.to_sym == :html || params[:controller] == 'messages'
    
    @display_messages = []
    
    unread_messages = current_user.messages.where( :read => false ).order( "last_sent DESC" )
    @unread_message_count = unread_messages.count
    
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

  # Utility method that allows a controller to add
  # meta information to a +target_object+ based on
  # the content of a form which has inputs named
  # like "meta[key1]" "meta[key2]" etc. The list of
  # keys we are looking for are supplied in +meta_keys+ ;
  # any other values present in the params[:meta] will
  # be ignored.
  #
  # Example: let's say that when posting to update object @myobj,
  # the also form sent this to the controller:
  #
  #   params = { :meta => { :abc => "2", :def => 'z', :xyz => 'A', :spa => "" } ... }
  #
  # Then calling
  #
  #   add_meta_data_from_form(@myobj, [ :def, :xyz, :nope, :spa ])
  #
  # will result in two meta data pieces of information added
  # to the object @myobj, and one of them deleted, like this:
  #
  #   @myobj.meta[:def] = 'z'
  #   @myobj.meta[:xyz] = 'A'
  #   @myobj.meta[:spa] = nil # which will delete the meta key
  #
  # This method is a wrapper around the method update_meta_data()
  # from module ActRecMetaData ; in particular, it supplies
  # the option :delete_on_blank by default, and extracts
  # by default the hash tables of value for +meta_params+ from
  # params[:meta]. See ActRecMetaData for more information.
  def add_meta_data_from_form(target_object, meta_keys = [], meta_params = nil, options = {})
    return true if meta_keys.empty?
    meta_params = meta_params.presence || params[:meta] || {}
    target_object.update_meta_data(meta_params, meta_keys, { :delete_on_blank => true }.merge(options))
  end

end

# Patch: Load all models so single-table inheritance works properly.
begin
  Dir.chdir(File.join(Rails.root.to_s, "app", "models")) do
    Dir.glob("*.rb").each do |model|
      model.sub!(/.rb$/,"")
      require_dependency "#{model}.rb" unless Object.const_defined? model.classify
    end
  end
  
  #Load userfile file types
  Dir.chdir(File.join(Rails.root.to_s, "app", "models", "userfiles")) do
    Dir.glob("*.rb").each do |model|
      model.sub!(/.rb$/,"")
      require_dependency "#{model}.rb" unless Object.const_defined? model.classify
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

