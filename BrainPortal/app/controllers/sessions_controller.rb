
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

require 'ipaddr'
require 'http_user_agent'
require 'oidc_config'

# Sesssions controller for the BrainPortal interface
# This controller handles the login/logout function of the site.
#
# Original author: restful_authentication plugin
# Modified by: Tarek Sherif
class SessionsController < ApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  api_available :only => [ :new, :show, :create, :destroy ]

  before_action      :user_already_logged_in,    :only => [ :new, :create ]
  skip_before_action :verify_authenticity_token, :only => [ :create ] # we invoke it ourselves in create()

  def new #:nodoc:
    reqenv           = request.env
    rawua            = reqenv['HTTP_USER_AGENT'] || 'unknown/unknown'
    ua               = HttpUserAgent.new(rawua)
    @browser_name    = ua.browser_name    || "(unknown browser name)"
    @browser_version = ua.browser_version || "(unknown browser version)"
    @oidc_providers  = OidcConfig.enabled

    respond_to do |format|
      format.html
      format.any { head :unauthorized }
    end
  end

  # GET /mandatory_globus
  # Shows the page that informs the user they MUST link to a Globus ID.
  def mandatory_globus #:nodoc:
    # Restrict @oidc_info to allowed providers
    @allowed_provs = allowed_globus_provider_names(current_user)
    @oidc_info = @oidc_info.select { |k,v| @allowed_provs.include?(k) }

    respond_to do |format|
      format.html
      format.any { head :unauthorized }
    end
  end

  def create #:nodoc:
    if ! api_request? # JSON is used for API calls; XML not yet fully supported
      verify_authenticity_token  # from Rails; will raise exception if not present.
    end
    user = User.authenticate(params[:login], params[:password]) # can be nil if it fails
    all_ok = create_from_user(user, 'CBRAIN')

    if ! all_ok
      auth_failed()
      return
    end

    # Record that the user connected using the CBRAIN login page
    cbrain_session[:login_page] = 'CBRAIN'

    respond_to do |format|
      format.html { redirect_back_or_default(start_page_path) }
      format.json { render :json => json_session_info, :status => 200 }
      format.xml  { render :xml  =>  xml_session_info, :status => 200 }
    end
  end

  def show #:nodoc:
    if current_user
      respond_to do |format|
        format.html { head   :ok                                                         }
        format.xml  { render :xml  =>  xml_session_info, :status => 200 }
        format.json { render :json => json_session_info, :status => 200 }
      end
    else
      head :unauthorized
    end
  end

  def destroy #:nodoc:
    unless current_user
      respond_to do |format|
        format.html { redirect_to new_session_path }
        format.xml  { head :unauthorized }
        format.json { head :unauthorized }
      end
      return
    end

    if current_user
      portal = BrainPortal.current_resource
      current_user.addlog("Logged out") if current_user
      portal.addlog("User #{current_user.login} logged out") if current_user
    end

    if cbrain_session
      cbrain_session.deactivate
      cbrain_session.clear
    end

    reset_session # Rails

    respond_to do |format|
      format.html {
                    flash[:notice] = "You have been logged out."
                    redirect_to new_session_path
                  }
      format.xml  { head :ok }
      format.json { head :ok }
    end
  end


  # This action receives a JSON authentication
  # request from globus and uses it to record or verify
  # a user's identity.
  def globus
    code      = params[:code].presence.try(:strip)
    state     = params[:state].presence || 'wrong'

    # Verifify state structure 33 + "_" + oidc_client_id
    # and extract client_id
    oidc_name = ""
    if state.length >= 34 && state[32] == '_'
      oidc_name = state[33..-1]
    end

    oidc = OidcConfig.find_by_name(oidc_name)

    # Some initial simple validations
    if !code || state != oidc.current_state
      cb_error "#{oidc.name} session is out of sync with CBRAIN"
    end

    token_uri = oidc.token_uri

    # Query Globus; this returns all the info we need at the same time.
    identity_struct = oidc.fetch_token(code, globus_url) # globus_url is generated from routes
    if !identity_struct
      cb_error "Could not fetch your identity information from #{oidc.name}"
    end
    Rails.logger.info "#{oidc.name} identity struct:\n#{identity_struct.pretty_inspect.strip}"

    # Either record the identity...
    if current_user
      if ! oidc.user_can_link_to_identity?(current_user, identity_struct)
        Rails.logger.error("User #{current_user.login} attempted authentication " +
                           "with unallowed #{oidc.name} identity provider " +
                           identity_struct[oidc.identity_provider_display_name].to_s)
        flash[:error] = "Error: your account can only authenticate with the following #{oidc.name} providers: " +
                        "#{allowed_globus_provider_names(current_user).join(", ")}"
        redirect_to user_path(current_user)
        return
      end
      oidc.record_identity(current_user, identity_struct)
      flash[:notice] = "Your CBRAIN account is now linked to your #{oidc.name} identity."
      if user_must_link_to_globus?(current_user)
        wipe_user_password_after_globus_link(current_user, oidc.name)
        flash[:notice] += "\nImportant note: from now on you can no longer connect to CBRAIN using a password."
        redirect_to start_page_path
        return
      end
      redirect_to user_path(current_user)
      return
    end

    # ...or attempt login with it
    user = oidc.find_user_with_oidc_identity(identity_struct)
    if user.is_a?(String) # an error occurred
      flash[:error] = user # the message
      redirect_to new_session_path
      return
    end

    login_from_globus_user(user, identity_struct[oidc.identity_provider_display_name])

  rescue CbrainException => ex
    flash[:error] = "#{ex.message}"
    redirect_to new_session_path
  rescue => ex
    clean_bt = Rails.backtrace_cleaner.clean(ex.backtrace || [])
    Rails.logger.error "#{oidc.name} auth failed: #{ex.class} #{ex.message} at #{clean_bt[0]}"
    flash[:error] = "The #{oidc.name} authentication failed"
    redirect_to new_session_path
  end

  # POST /unlink_oidc
  # Removes a user's linked OIDC identity.
  def unlink_oidc #:nodoc:
    redirect_to start_page_path unless current_user

    oidc = OidcConfig.find_by_name(params[:oidc_name])
    oidc.unlink_identity(current_user)

    flash[:notice] = "Your account is no longer linked to any #{oidc.name} identity"
    redirect_to start_page_path
  end

  ###############################################
  #
  # Private methods
  #
  ###############################################

  private

  def user_already_logged_in #:nodoc:
    if current_user
      respond_to do |format|
        format.html { redirect_to start_page_path }
        format.json { render :json => json_session_info, :status => 200 }
        format.xml  { render :xml  =>  xml_session_info, :status => 200 }
      end
    end
  end

  # Does all sort of housekeeping and checks when +user+ logs in.
  # If user is nil, tells the framework the authentication has failed.
  # +origin+ is a keyword describing the origin of the authentication
  # for the user.
  def create_from_user(user, origin='CBRAIN') #:nodoc:

    # Bad login/password?
    unless user
      flash.now[:error] = 'Invalid user name or password.'
      Kernel.sleep 3 # Annoying, as it blocks the instance for other users too. Sigh.
      return false
    end

    # Not in IP whitelist?
    whitelist = (user.meta[:ip_whitelist] || '')
      .split(',')
      .map { |ip| IPAddr.new(ip.strip) rescue nil }
      .reject(&:blank?)
    if whitelist.present? && ! whitelist.any? { |ip| ip.include? cbrain_request_remote_ip }
      flash.now[:error] = 'Untrusted source IP address.'
      return false
    end

    # Check if the user or the portal is locked
    portal = BrainPortal.current_resource
    locked_message  = portal_or_account_locked?(portal,user)
    if locked_message.present?
      flash[:error] = locked_message
      return false
    end

    # Everything OK
    self.current_user = user # this ALSO ACTIVATES THE SESSION
    session[:user_id] = user.id  if request.format.to_sym == :html
    user_tracking(portal, origin) # Figures out IP address, user agent, etc, once.

    return true

  end

  # Send a proper HTTP error code
  # when a user has not properly authenticated
  def auth_failed
    @oidc_providers = OidcConfig.enabled
    respond_to do |format|
      format.html { render :action => 'new', :status => :ok } # should it be :unauthorized ?
      format.json { head   :unauthorized }
      format.xml  { head   :unauthorized }
    end
  end

  def portal_or_account_locked?(portal,user) #:nodoc:

    # Portal locked?
    if portal.portal_locked? && !user.has_role?(:admin_user)
      return "The system is currently locked. Please try again later."
    end

    # Account locked?
    if user.account_locked?
      return "This account is locked, please write to #{User.admin.email.presence || "the support staff"} to get this account unlocked."
    end

    return ""
  end

  def user_tracking(portal,origin='CBRAIN') #:nodoc:
    user   = current_user
    cbrain_session.activate(user.id)

    # Record the best guess for browser's remote host IP and name
    reqenv      = request.env
    from_ip     = cbrain_request_remote_ip rescue nil
    from_host   = hostname_from_ip(from_ip)
    from_ip   ||= '0.0.0.0'
    from_host ||= 'unknown'
    cbrain_session[:guessed_remote_ip]   = from_ip
    cbrain_session[:guessed_remote_host] = from_host
    cbrain_session.remote_resource_id    = portal.id # for general navigation help

    # Record the user agent
    raw_agent = reqenv['HTTP_USER_AGENT'] || 'unknown/unknown'
    cbrain_session[:raw_user_agent]      = raw_agent

    # Record that the user logged in
    parsed         = HttpUserAgent.new(raw_agent)
    browser        = (parsed.browser_name    || 'unknown browser')
    brow_ver       = (parsed.browser_version || '?')
    os             = (parsed.os_name         || 'unknown OS')
    pretty_brow    = "#{browser} #{brow_ver} on #{os}"
    pretty_host    = "#{from_ip}"
    if (from_host != 'unknown' && from_host != from_ip)
       pretty_host = "#{from_host} (#{pretty_host})"
    end

    # The authentication_mechanism is a string which describes
    # the mechanism that was used by the user to log in.
    authentication_mechanism = "password" # in future this could change

    # In case of logins though the API, record that in the session too.
    if api_request?
      cbrain_session[:api] = 'yes'
      authentication_mechanism = 'password/api'
    end

    # The following two log lines differ at their beginning but provides
    # the same information afterwards. Thus the weird style alignment.
    user.addlog(      "Logged in on #{portal.name}/#{origin} with #{authentication_mechanism} from #{pretty_host} using #{pretty_brow}")
    portal.addlog("User #{user.login} logged in on #{origin} with #{authentication_mechanism} from #{pretty_host} using #{pretty_brow}")
    user.update_column(:last_connected_at, Time.now)

    # Admin users start with some differences in behavior
    if user.has_role?(:admin_user)
      cbrain_session[:active_group_id] = "all"
    end
  end


  def login_from_globus_user(user, provider_name)
    # Login the user
    all_ok = create_from_user(user, "CBRAIN/Globus/#{provider_name}")

    if ! all_ok
      redirect_to new_session_path
      return
    end

    # Record that the user connected using the CBRAIN login page
    cbrain_session[:login_page] = 'CBRAIN'

    # All's good
    redirect_to start_page_path
  end

  # ------------------------------------
  # SessionInfo fake model for API calls
  # ------------------------------------

  def session_info #:nodoc:
    {
      :user_id          => current_user.try(:id),
      :cbrain_api_token => cbrain_session.try(:cbrain_api_token),
    }
  end

  def xml_session_info #:nodoc:
    session_info.to_xml(:root => 'SessionInfo', :dasherize => false)
  end

  def json_session_info #:nodoc:
    session_info
  end

end

