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

  helper_method :check_role, :not_admin_user, :current_session, :current_project
  helper_method :to_localtime, :pretty_elapsed, :pretty_past_date, :pretty_size, :red_if
  helper        :all # include all helpers, all the time

 filter_parameter_logging :password, :login, :email, :full_name, :role

  before_filter :set_cache_killer
  before_filter :check_if_locked
  before_filter :prepare_messages
  before_filter :set_session
  before_filter :password_reset
  before_filter :adjust_system_time_zone
  around_filter :catch_cbrain_message, :activate_user_time_zone
    
  # See ActionController::RequestForgeryProtection for details
  # Uncomment the :secret if you're not using the cookie session store
  protect_from_forgery :secret => 'b5e7873bd1bd67826a2661e01621334b'
  
  

  ########################################################################
  # Controller Filters
  ########################################################################

  private

  # This method adjust the Rails app's time zone in the rare
  # cases where the admin has changed it in the DB using the
  # interface.
  def adjust_system_time_zone
    myself = RemoteResource.current_resource
    syszone = myself.time_zone
    return true unless syszone && ActiveSupport::TimeZone[syszone]
    if Time.zone.blank? || Time.zone.name != syszone
      puts "\e[1;33;41mRESETTING TIME ZONE FROM #{Time.zone.name rescue "unset"} to #{syszone}.\e[0m"
      Rails.configuration.time_zone = syszone
      Rails::Initializer.new(Rails.configuration).initialize_time_zone
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
    return yield unless userzone && ActiveSupport::TimeZone[userzone] # nothing to do if no user zone or zone is incorrent
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
  
  ########################################################################
  # CBRAIN Exception Handling (Filters)
  ########################################################################

  #Catch and display cbrain messages
  def catch_cbrain_message
    begin
      yield
    rescue ActiveRecord::RecordNotFound => e
      raise if ENV['RAILS_ENV'] == 'development' #Want to see stack trace in dev.
      flash[:error] = "The object you requested does not exist or is not accessible to you."
      redirect_to default_redirect
    rescue ActionController::UnknownAction => e
      raise if ENV['RAILS_ENV'] == 'development' #Want to see stack trace in dev.
      flash[:error] = "The page you requested does not exist."
      redirect_to default_redirect
    rescue CbrainException => cbm
      if cbm.is_a? CbrainNotice
         flash[:notice] = cbm.message    # + "\n" + cbm.backtrace[0..5].join("\n")
      else
         flash[:error]  = cbm.message    # + "\n" + cbm.backtrace[0..5].join("\n")
      end
      respond_to do |format|
        format.html { redirect_to cbm.redirect || default_redirect }
        format.js   { render :partial  => "shared/flash_update" } 
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
  
  def default_redirect
    if self.respond_to?(:index) && params[:action] != "index"
      {:action => :index}
    else
      home_path
    end
  end
  
  ########################################################################
  # CBRAIN Messaging System Filters
  ########################################################################

  def check_if_locked
    if BrainPortal.current_resource.portal_locked?
      flash.now[:error] ||= ""
      flash.now[:error] += "\n" unless flash.now[:error].blank?
      flash.now[:error] += "This portal is currently locked for maintenance."
    end
  end
    
  def prepare_messages

    return unless current_user
    return unless request.format.to_sym == :html || params[:controller] == 'messages'
    
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
    
  ########################################################################
  # Helpers
  ########################################################################

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
  
  #Returns currently active project.
  def current_project
    return nil unless current_session[:active_group_id]
    
    if !@current_project || @current_project.id.to_i != current_session[:active_group_id].to_i
      @current_project = Group.find(current_session[:active_group_id])
    end
    
    @current_project
  end
  
  #Helper method to render and error page. Will render public/<+status+>.html
  def access_error(status)
      render(:file => (RAILS_ROOT + '/public/' + status.to_s + '.html'), :status  => status)
  end
  
  #################################################################################
  # Date/Time Helpers
  #################################################################################
  
  #Converts any time string or object to the format 'yyyy-mm-dd hh:mm:ss'.
  def to_localtime(stringtime, what = :date)
     loctime = stringtime.is_a?(Time) ? stringtime : Time.parse(stringtime.to_s)
     loctime = loctime.in_time_zone # uses the user's time zone, or the system if not set. See activate_user_time_zone()
     if what == :date || what == :datetime
       date = loctime.strftime("%Y-%m-%d")
     end
     if what == :time || what == :datetime
       time = loctime.strftime("%H:%M:%S %Z")
     end
     case what
       when :date
         return date
       when :time
         return time
       when :datetime
         return "#{date} #{time}"
       else
         raise "Unknown option #{what.to_s}"
     end
  end

  # Returns a string that represents the amount of elapsed time
  # encoded in +numseconds+ seconds.
  #
  # 0:: "0 seconds"
  # 1:: "1 second"
  # 7272:: "2 hours, 1 minute and 12 seconds"
  def pretty_elapsed(numseconds)
    remain = numseconds.to_i

    return "0 seconds" if remain <= 0

    numweeks = remain / 1.week
    remain   = remain - ( numweeks * 1.week   )

    numdays  = remain / 1.day
    remain   = remain - ( numdays  * 1.day    )

    numhours = remain / 1.hour
    remain   = remain - ( numhours * 1.hour   )

    nummins  = remain / 1.minute
    remain   = remain - ( nummins  * 1.minute )

    numsecs  = remain

    components = [
      [numweeks, "week"],
      [numdays,  "day"],
      [numhours, "hour"],
      [nummins,  "minute"],
      [numsecs,  "second"]
    ]

    components = components.select { |c| c[0] > 0 }

    final = ""

    while components.size > 0
      comp = components.shift
      num  = comp[0]
      unit = comp[1]
      unit += "s" if num > 1
      unless final.blank?
        if components.size > 0
          final += ", "
        else
          final += " and "
        end
      end
      final += "#{num} #{unit}"
    end

    final
  end

  # Returns +pastdate+ as as pretty date or datetime with an
  # amount of time elapsed since then expressed in parens
  # just after it, e.g.,
  #
  #    "2009-12-31 11:22:33 (3 days 2 hours 27 seconds ago)"
  def pretty_past_date(pastdate, what = :datetime)
    loctime = pastdate.is_a?(Time) ? pastdate : Time.parse(pastdate.to_s)
    locdate = to_localtime(pastdate,what)
    elapsed = pretty_elapsed(Time.now - loctime)
    "#{locdate} (#{elapsed} ago)"
  end
  
  # Format a byte size for display in the view.
  # Returns the size as one of
  #   12.3 GB
  #   12.3 MB
  #   12.3 KB
  #   123 bytes
  def pretty_size(size)
    if size.blank?
      "unknown"
    elsif size >= 1_000_000_000
      sprintf "%6.1f GB", size/(1_000_000_000 + 0.0)
    elsif size >=     1_000_000
      sprintf "%6.1f MB", size/(    1_000_000 + 0.0)
    elsif size >=         1_000
      sprintf "%6.1f KB", size/(        1_000 + 0.0)
    else
      sprintf "%d bytes", size
    end 
  end

  # Returns one of two things depending on +condition+:
  # If +condition+ is FALSE, returns +string1+
  # If +condition+ is TRUE, returns +string2+ colorized in red.
  # If no +string2+ is supplied, then it will be considered to
  # be the same as +string1+.
  # Options can be use to specify other colors (as :color1 and
  # :color2, respectively)
  #
  # Examples:
  #
  #     red_if( ! is_alive? , "Alive", "Down!" )
  #
  #     red_if( num_matches == 0, "#{num_matches} found" )
  def red_if(condition,string1,string2 = string1, options = { :color2 => 'red' } )
    if condition
      color = options[:color2] || 'red'
      string = string2 || string1
    else
      color = options[:color1]
      string = string1
    end
    if color
      color = "style=\"color:#{color}\""
    end
    return "<span #{color}>#{string}</span>"
  end

  # Utility method that allows a controller to add
  # meta information to a +target_object+ based on
  # the content of a form which has inputs named
  # like "meta[key1]" "meta[key2]" etc. The list of
  # keys we are looking for are supplied in meta_keys;
  # any other values present in the params[:meta] will
  # be ignored.
  #
  # Example: let's say that when posting to update object @myobj,
  # the form sent also contained this:
  #
  #   params = { :meta => { :abc => "2", :def => 'z', :xyz => 'A' } ... }
  #
  # Then calling
  #
  #   add_meta_data_from_form(@myobj, [ :def, :xyz ])
  #
  # will result in two meta data pieces of information added
  # to the object @myobj, like this:
  #
  #   @myobj.meta[:def] = 'z'
  #   @myobj.meta[:xyz] = 'A'
  #
  # See ActRecMetaData for more information.
  def add_meta_data_from_form(target_object, meta_keys = [], myparams = params)
    return true if meta_keys.empty?
    form_meta = myparams[:meta] || {}
    meta_keys.each do |key|
      target_object.meta[key] = form_meta[key] # assignment of nil deletes the key
    end
    true
  end

end

# Patch: Load all models so single-table inheritance works properly.
begin
  Dir.chdir(File.join(RAILS_ROOT, "app", "models")) do
    Dir.glob("*.rb").each do |model|
      model.sub!(/.rb$/,"")
      require_dependency "#{model}.rb" unless Object.const_defined? model.classify
    end
  end
  
  #Load userfile file types
  Dir.chdir(File.join(RAILS_ROOT, "app", "models", "userfiles")) do
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

LoggedExceptionsController.class_eval do
  # set the same session key as the app
  session :session_key => Rails.configuration.action_controller[:session][:session_key]
  
  include AuthenticatedSystem

  protect_from_forgery :secret => Rails.configuration.action_controller[:session][:secret]

  before_filter :login_required, :admin_role_required

  # optional, sets the application name for the rss feeds
  self.application_name = "BrainPortal"
end
