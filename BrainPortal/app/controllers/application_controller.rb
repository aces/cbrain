
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

# Superclass to all *BrainPortal* controllers. Contains
# helper methods for checking various aspects of the current
# session.
class ApplicationController < ActionController::Base

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  include AuthenticatedSystem
  include RequestHelpers
  include SessionHelpers
  include ViewScopes
  include PersistentSelection
  include ViewHelpers
  include ApiHelpers
  include PermissionHelpers
  include ExceptionHelpers
  include MessageHelpers
  include GlobusHelpers

  helper_method :start_page_path

  # These will be executed in order
  before_action :check_account_validity
  before_action :prepare_messages
  before_action :adjust_system_time_zone
  before_action :adjust_remote_ip_and_host
  before_action :disable_cookies_for_api   # prevent sending back the session cookie for API requests

  # This wraps the main action
  around_action :activate_user_time_zone

  # These will be executed in REVERSE of the order listed here
  after_action  :update_session_info       # touch timestamp of session at least once per minute
  after_action  :action_counter            # counts all action/controller/user agents
  after_action  :log_user_info             # add to log a single line with user info.

  protect_from_forgery with: :exception, unless: -> { request.format.json? || request.format.xml? }

  rescue_from CbrainLicenseException, with: :redirect_show_license


    ########################################################################
  # Controller Filters
  ########################################################################

  private


  def redirect_show_license
    #
    if params[:id].present? && params[:controller] == "groups"
      redirect_to show_license_group_path(params[:id])
    else
      redirect_to groups_path
    end
  end

  # Re-compute the host and IP from the request (when not logged in, or changed)
  def adjust_remote_ip_and_host #:nodoc:
    from_ip = cbrain_session[:guessed_remote_ip].presence || '(None)' # what we had previously
    cur_ip  = cbrain_request_remote_ip rescue nil
    if cur_ip.present? && from_ip != cur_ip # changed?
      cur_host = hostname_from_ip(cur_ip)
      cbrain_session[:guessed_remote_ip]   = cur_ip
      cbrain_session[:guessed_remote_host] = cur_host
      current_user.addlog("IP address changed: #{from_ip} to #{cur_ip}") if current_user
    end
    true
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

  # Check if the user needs to change their password
  # or sign license agreements.
  def check_account_validity #:nodoc:
    return false unless current_user
    return true  if     params[:controller] == "sessions"
    return false unless check_mandatory_globus_id_linkage()
    return false unless check_password_reset()
    return false unless check_license_agreements()
    return true
  end

  # Check to see if the user HAS to link their account to
  # a globus identity. If that's the case and not yet done,
  # redirects to the page that provides the user with the
  # buttons and explanations.
  def check_mandatory_globus_id_linkage #:nodoc:
    return true if ! user_must_link_to_globus?(current_user)
    return true if   user_has_link_to_globus?(current_user)
    respond_to do |format|
      format.html { redirect_to :controller => :sessions, :action => :mandatory_globus }
      format.json { render :status => 403, :json => { "error" => "This account must first be linked to a Globus identity" } }
      format.xml  { render :status => 403, :xml  => { "error" => "This account must first be linked to a Globus identity" } }
    end
    return false
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
          format.json { render :status => 403, :json => { "error" => "Some license agreements are not signed." } }
          format.xml  { render :status => 403, :xml  => { "error" => "Some license agreements are not signed." } }
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
  #
  # The message looks like
  #
  #  "User: tsmith on instance C4044 from example.com (256.0.0.9) using FireChrome 99.9"
  def log_user_info #:nodoc:
    reqenv = request.env || {}

    # Short username for the message
    login  = current_user ? current_user.login : "(none)"

    # Find out the instance name
    instname = CBRAIN::Instance_Name rescue "(?)"

    # Get host and IP from session (when logged in)
    from_ip   = cbrain_session[:guessed_remote_ip].presence
    from_host = cbrain_session[:guessed_remote_host].presence

    # Pretty user agent string
    brow  = parsed_http_user_agent.browser_name.presence    || "(UnknownClient)"
    b_ver = parsed_http_user_agent.browser_version.presence

    # Create final message
    from  = (from_host.present? && from_host != from_ip) ? "#{from_host} (#{from_ip})" : from_ip
    mess  = "User: #{login} on instance #{instname} from #{from} using #{brow} #{b_ver}"
    Rails.logger.info mess
    true
  rescue => ex
    Rails.logger.error "#{ex.class}: #{ex.message}\n#{ex.backtrace[0..2].join("\n")}"
  end

  # Returns a HttpUserAgent object with the parsed info from ENV['HTTP_USER_AGENT']
  def parsed_http_user_agent #:nodoc:
    @_http_user_agent_ ||= HttpUserAgent.new((request.env || {})['HTTP_USER_AGENT'] || 'unknown/unknown')
  end

  # Returns (and caches) the DNS hostname associated with an IP "aaa.bbb.ccc.ddd"
  # Returns ip as-is if ip is not an IP address, or lookup fails.
  def hostname_from_ip(ip) # :nodoc:
    return ip if ip.blank? || ip !~ /\A\d+\.\d+\.\d+\.\d+\z/
    host = Rails.cache.fetch("host_addr/#{ip}", expires_in: 24.hours) do
      Socket.gethostbyaddr(ip.split(/\./).map(&:to_i).pack("CCCC")).try(:first) rescue ip
    end
    host = ip if host.size < 2 # seen weird "." as a result of lookup
    host
  rescue
    ip
  end

  # 'After' callback: store a hash in the metadata of the session, in order
  # to keep the count of each action by controller and by client_type.
  def action_counter #:nodoc:
    # Extract information about controller and action
    client_type            = parsed_http_user_agent.browser_name.presence || "(UnknownClient)"
    controller             = params[:controller].to_s.presence            || "UnknownController"
    action                 = params[:action].to_s.presence                || "UnknownAction"
    success                = response.code.to_s =~ /\A[123]\d\d\z/

    # Fetch the stats structure from meta data
    current_resource       = RemoteResource.current_resource
    cr_meta                = current_resource.meta
    cr_meta.reload
    stats                  = cr_meta[:stats] || {}

    # Fill the stats structure, initializing the levels as we go.

    # Simple success/failure counts by user agents
    stats['UserAgents']                              ||= {}
    stats['UserAgents'][client_type]                 ||= [0,0]
    stats['UserAgents'][client_type][success ? 0 : 1] += 1

    # As of 2022 we don't record controller and actions by user agent; instead
    # they all go under 'AllAgents'
    stats['AllAgents']          ||= {}
    contr2action                  = stats['AllAgents']
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

  # 'After' callback. For the moment only adjusts the timestamp
  # on the current session, to detect active users. If the user
  # is only doing GET requests, the session object is not updated,
  # so this will touch it once per minute.
  def update_session_info
    cbrain_session.try(:touch_unless_recent)
  rescue # ignore all errors.
    true
  end

  # 'Before' callback. When using API requests, we never send back
  # the session cookie.
  def disable_cookies_for_api
    request.session_options[:skip] = true if api_request?
    true
  end



  ########################################################################
  # CBRAIN Messaging System Filters
  ########################################################################

  # Find new messages and prepare them to be displayed at the top of the page.
  def prepare_messages #:nodoc:
    return unless current_user
    return if     current_user.all_licenses_signed.blank?
    return if     request.format.blank? || request.xhr?
    return unless request.format.to_sym == :html || params[:controller] == 'messages'

    @display_messages = []

    unread_messages = unread_messages_to_display
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

  def unread_messages_to_display #:nodoc:
    current_user.messages
      .where( :read => false, :message_type => [ 'communication', 'notice', 'error', 'system' ] )
      .order( "last_sent DESC" )
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

  # Home pages in hash form.
  def start_page_params #:nodoc:
    if current_user.blank?
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
  def extract_params_key(list=[], default=nil) #:nodoc:
    list.detect { |x| params.has_key?(x) && x } || default
  end

  # Messy utility, poking through layers. Tricky and brittle.
  def eval_in_controller(mycontroller, options={}, &block) #:nodoc:
    cb_error "Controller is not a ApplicationController?" unless mycontroller < ApplicationController
    cb_error "Block needed." unless block_given?
    context = mycontroller.new
    context.request = self.request
    if options.has_key?(:define_current_user)
      context.define_singleton_method(:current_user) { options[:define_current_user] }
    end
    context.instance_eval(&block)
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
  if error.to_s.match(/Mysql.*Table.*doesn't exist/i)
    puts "Skipping model load:\n\t- Database table doesn't exist yet. It's likely this system is new and the migrations have not been run yet."
  elsif error.to_s.match(/Unknown database/i)
    puts "Skipping model load:\n\t- System database doesn't exist yet. It's likely this system is new and the migrations have not been run yet."
  else
    raise
  end
end

