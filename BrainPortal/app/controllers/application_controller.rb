
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

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  include AuthenticatedSystem
  include SessionHelpers
  include ViewScopes
  include ViewHelpers
  include ApiHelpers
  include PermissionHelpers
  include ExceptionHelpers
  include MessageHelpers

  helper        :all # include all helpers, all the time
  helper_method :start_page_path

  before_filter :set_cache_killer
  before_filter :check_account_validity
  before_filter :prepare_messages
  before_filter :adjust_system_time_zone
  around_filter :activate_user_time_zone
  after_filter  :action_counter # depends on log_user_info to compute client_type in session
  after_filter  :log_user_info
  before_filter :login_required, :only => :filter_proxy

  # See ActionController::RequestForgeryProtection for details
  # Uncomment the :secret if you're not using the cookie session store
  protect_from_forgery :secret => 'b5e7873bd1bd67826a2661e01621334b'


  def filter_proxy #:nodoc:
    redirect_to(:controller  => params[:proxy_destination_controller],
                :action      => params[:proxy_destination_action] || "index",
                :id          => params[:proxy_destination_id])
  end

  ########################################################################
  # Controller Filters
  ########################################################################

  private

  # Returns the name of the model class associated with a given contoller. By default
  # takes the name from the name of the controller, but can be redefined in subclasses
  # as needed.
  def resource_class #:nodoc:
    @resource_class ||= Class.const_get self.class.to_s.sub(/Controller$/, "").singularize
  end

  # This method adjust the Rails app's time zone in the rare
  # cases where the admin has changed it in the DB using the
  # interface.
  def adjust_system_time_zone #:nodoc:
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
  def set_cache_killer #:nodoc:
    # (no-cache) Instructs the browser not to cache and get a fresh version of the resource
    # (no-store) Makes sure the resource is not stored to disk anywhere - does not guarantee that the
    # resource will not be written
    # (must-revalidate) the cache may use the response in replying to a subsequent request but if the resonse is stale
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
    response.headers["X-CBRAIN-Instance-Name" ] = CBRAIN::Instance_Name
  end

  # Check if the user needs to change their password
  # or sign license agreements.
  def check_account_validity #:nodoc:
    return false unless current_user
    return true  if     params[:controller] == "sessions"
    return false unless check_password_reset()
    return false unless check_license_agreements()
    return true
  end

  def check_license_agreements #:nodoc:

    current_user.meta.reload
    return true if current_user.all_licenses_signed.present?
    return true if params[:controller] == "portal" && params[:action] =~ /license$/
    return true if params[:controller] == "users"  && (params[:action] == "change_password" || params[:action] == "update")

    unsigned_agreements = current_user.unsigned_license_agreements
    unless unsigned_agreements.empty?
      if File.exists?(Rails.root + "public/licenses/#{unsigned_agreements.first}.html")
        respond_to do |format|
          format.html { redirect_to :controller => :portal, :action => :show_license, :license => unsigned_agreements.first }
          format.json { render :status => 403, :text => "Some license agreements are not signed." }
          format.xml  { render :status => 403, :text => "Some license agreements are not signed." }
        end
        return false
      end
    end

    current_user.all_licenses_signed = "yes"
    return true
  end

  # Check if password need to be reset.
  def check_password_reset #:nodoc:
    if current_user.password_reset
      unless params[:controller] == "users" && (params[:action] == "change_password" || params[:action] == "update")
        flash[:error] = "Please reset your password."
        redirect_to change_password_user_path(current_user)
        return false
      end
    end
    return true
  end

  # 'After' callback: logs in the Rails logger information about the user who
  # just performed the request.
  def log_user_info #:nodoc:
    reqenv = request.env
    login  = current_user ? current_user.login : "(none)"

    # Get some info from session (when logged in)
    ip     = current_session["guessed_remote_ip"]
    host   = current_session["guessed_remote_host"] # only set when logged in

    # Compute the info from the request (when not logged in)
    ip   ||= reqenv['HTTP_X_FORWARDED_FOR'] || reqenv['HTTP_X_REAL_IP'] || reqenv['REMOTE_ADDR']
    if host.blank? && ip =~ /^[\d\.]+$/
      addrinfo = Rails.cache.fetch("host_addr/#{ip}") do
        Socket.gethostbyaddr(ip.split(/\./).map(&:to_i).pack("CCCC")) rescue [ ip ]
      end
      host = addrinfo[0]
    end

    # Pretty user agent string
    rawua = reqenv['HTTP_USER_AGENT'] || 'unknown/unknown'
    ua    = HttpUserAgent.new(rawua)
    brow  = ua.browser_name           || "(UnknownClient)"
    current_session["client_type"]     = brow  # used by action_counter() below
    b_ver = ua.browser_version

    # Find out the instance name
    instname = CBRAIN::Instance_Name rescue "(?)"

    # Create final message
    from  = (host.presence && host != ip) ? "#{host} (#{ip})" : ip
    mess  = "User: #{login} on instance #{instname} from #{from} using #{brow} #{b_ver.presence}"
    Rails.logger.info mess
    true
  rescue
    true
  end

  # 'After' callback: store a hash in the metadata of the session, in order
  # to keep the count of each action by controller and by client_type.
  def action_counter #:nodoc:
    # Extract information about controller and action
    client_type            = current_session["client_type"] # this is set in log_user_info() above.
    return true if client_type.blank?

    controller             = params[:controller].to_s.presence   || "UnknownController"
    action                 = params[:action].to_s.presence       || "UnknownAction"
    success                = response.code.to_s =~ /^[123]\d\d$/

    # Fetch the stats structure from meta data
    current_resource       = RemoteResource.current_resource
    cr_meta                = current_resource.meta
    cr_meta.reload
    stats                  = cr_meta[:stats] || {}

    # Fill the stats structure, initializing the levels as we go.
    stats[client_type]          ||= {}
    contr2action                  = stats[client_type]
    contr2action[controller]    ||= {}
    action2count                  = contr2action[controller]
    action2count[action]        ||= [0,0]
    action2count[action][success ? 0 : 1] += 1

    # Global counts, by response codes
    stats["GlobalCount"]                     ||= 0
    stats["GlobalCount"]                      += 1     # Important to change at least ONE entry at top level, so meta data saves...
    stats["StatusCodes"]                     ||= {}
    stats["StatusCodes"]["status_#{response.code.to_s}"] ||= 0
    stats["StatusCodes"]["status_#{response.code.to_s}"]  += 1

    # Save back the structure
    cr_meta[:stats] = stats   # ... here.
    true
  rescue => ex
    puts_red "Ex: #{ex.class} #{ex.message}\n#{ex.backtrace.join("\n")}"
    true
  end


  ########################################################################
  # CBRAIN Messaging System Filters
  ########################################################################

  # Find new messages to be displayed at the top of the page.
  def prepare_messages #:nodoc:
    return unless current_user
    return if     current_user.all_licenses_signed.blank?
    return if     request.format.blank? || request.xhr?
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
  # the form also sent this to the controller:
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
  def add_meta_data_from_form(target_object, meta_keys = [], meta_params = nil, options = {}) #:nodoc:
    return true if meta_keys.empty?
    meta_params = meta_params.presence || params[:meta] || {}
    target_object.update_meta_data(meta_params, meta_keys, { :delete_on_blank => true }.merge(options))
  end

  ####################################################
  #
  # Changing default redirect code from 302 to 303
  #
  ####################################################

  alias :old_redirect_to :redirect_to

  # Change default redirect code to 303
  def redirect_to(options = {}, response_status = {}) #:nodoc:
    if options.is_a?(Hash)
      options[:status] ||= 303
    else
      response_status[:status] ||= 303
    end
    old_redirect_to(options, response_status)
  end

  # Home pages in hash form.
  def start_page_params #:nodoc:
    if current_user.nil?
      { :controller => :sessions, :action => :new }
    elsif current_user.has_role?(:normal_user)
      { :controller => :groups, :action => :index }
    else
      { :controller => :portal, :action => :welcome }
    end
  end

  # Different home pages for admins and other users.
  def start_page_path #:nodoc:
    url_for(start_page_params)
  end

  ####################################################
  #
  # General params handler helper
  #
  ####################################################

  # Use in order to return param key if it's present in params
  def extract_params_key (list=[], default=nil) #:nodoc:
    list.detect { |x| params.has_key?(x) && x } || default
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
rescue => error
  if error.to_s.match(/Mysql::Error.*Table.*doesn't exist/i)
    puts "Skipping model load:\n\t- Database table doesn't exist yet. It's likely this system is new and the migrations have not been run yet."
  elsif error.to_s.match(/Unknown database/i)
    puts "Skipping model load:\n\t- System database doesn't exist yet. It's likely this system is new and the migrations have not been run yet."
  else
    raise
  end
end

