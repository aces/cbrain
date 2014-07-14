
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

# Sesssions controller for the BrainPortal interface
# This controller handles the login/logout function of the site.
#
# Original author: restful_authentication plugin
# Modified by: Tarek Sherif
class SessionsController < ApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  before_filter :no_logged_in_user, :only => [:new, :create]

  api_available

  def new #:nodoc:
    reqenv   = request.env
    rawua    = reqenv['HTTP_USER_AGENT'] || 'unknown/unknown'
    ua       = HttpUserAgent.new(rawua)
    @browser = ua.browser_name    || "(unknown browser)"

    respond_to do |format|
      format.html
      format.xml
      format.json { render :json => {:authenticity_token => form_authenticity_token} }
      format.txt
    end
  end

  def create
    create_from_user(User.authenticate(params[:login], params[:password]))
  end

  def show #:nodoc:
    if current_user
      respond_to do |format|
        format.html { render :nothing => true, :status => 200 }
        format.xml  { render :xml  => {:user_id => current_user.id}, :status => 200 }
        format.json { render :json => {:user_id => current_user.id}, :status => 200 }
      end
    else
      render :nothing  => true, :status  => 401
    end
  end

  def destroy #:nodoc:
    unless current_user
      redirect_to new_session_path
      return
    end

    portal = BrainPortal.current_resource
    current_session.deactivate if current_session
    current_user.addlog("Logged out") if current_user
    portal.addlog("User #{current_user.login} logged out") if current_user
    self.current_user.forget_me if logged_in?
    cookies.delete :auth_token
    current_session.clear_data!
    #reset_session
    flash[:notice] = "You have been logged out."

    respond_to do |format|
      format.html { redirect_to new_session_path }
      format.xml  { render :nothing => true, :status  => 200 }
      format.json { render :nothing => true, :status  => 200 }
    end
  end

  ###############################################
  #
  # Mozilla Persona authentication
  #
  ###############################################

  # This method handles the Mozilla Persona assertion posted by the JavaScript login function
  def mozilla_persona_auth #:nodoc:
    assertion = params[:assertion]
    data = verify_assertion(assertion)
    if data["status"] == "okay"
      auth_success(data["email"])
    else
      auth_failed
    end
    return
  end

  # Mozilla currently recommend to use their remote validation service
  # Ultimately this should be built in the code
  # Do NOT send the assertion on a non HTTP*S* connection
  # Adapted the code of this method from https://github.com/chilts/browserid-verify-ruby
  def verify_assertion(assertion) #:nodoc:

    # TODO put this in config file
    url      = "https://verifier.login.persona.org/verify"
    audience = "#{request.protocol}#{request.host_with_port}#{request.fullpath}"
    uri      = URI.parse(url)

    # make a new request
    request = Net::HTTP::Post.new(uri.path)
    request.set_form_data({"audience" => audience, "assertion" => assertion})

    # send the request
    https         = Net::HTTP.new(uri.host,uri.port)
    https.use_ssl = true
    response      = https.request(request)

    # if we have a non-200 response
    if ! response.kind_of? Net::HTTPSuccess
      return {
        "status" => "failure",
        "reason" => "Cannot verify request",
        "body"   => response.body
      }
    end

    # process the response
    data = JSON.parse(response.body) || nil
    if data.nil?
      # JSON parsing error
      return  {"status" => "failure", "reason" => "Received invalid JSON from the remote verifier"}
    end

    return data
  end

  # We could authenticate the email
  # Now, let's check if there is a user associated to it
  # Be careful NOT to grant admin access based on Mozilla Persona.
  def auth_success(email) #:nodoc:
    user = User.where(:email => email, :type => "NormalUser").first
    if user.blank?
      flash[:error] = 'Cannot find CBRAIN user associated to this email address.'
      inexistent_user
    else
      self.current_user = user
      # Check if the user or the portal is locked
      portal = BrainPortal.current_resource
      locked_message = account_or_portal_locked?(portal)
      if !locked_message.blank?
        flash[:error] = locked_message
        respond_to do |format|
          format.html { render :action => 'new' }
          format.json { render :nothing => true, :status  => 401 }
          format.xml  { render :nothing => true, :status  => 401 }
        end
        return
      end

      # Everything OK
      user_tracking(portal)

      respond_to do |format|
        format.html { redirect_back_or_default(start_page_path) }
        format.json { render :json => {:session_id => request.session_options[:id]}, :status => 200 }
        format.xml  { render :nothing => true, :status  => 200 }
      end
    end
  end

  # Send a proper HTTP error code
  def auth_failed #:nodoc:
    flash[:error] = 'Authentication failed.'
    respond_to do |format|
      format.html { render :action  => 'new', :status  => 200 }
      format.json { render :nothing => true,  :status  => 200 }
      format.xml  { render :nothing => true,  :status  => 200 }
    end
  end

  # Send a proper HTTP error code
  def inexistent_user #:nodoc:
    respond_to do |format|
      format.html { render :action  => 'new', :status  => 200 }
      format.json { render :nothing => true,  :status  => 200 }
      format.xml  { render :nothing => true,  :status  => 200 }
    end
  end

  ###############################################
  #
  # Private methods
  #
  ###############################################

  private

  def no_logged_in_user #:nodoc:
    if current_user
      redirect_to start_page_path
    end
  end

  def create_from_user(user)
    portal = BrainPortal.current_resource

    self.current_user = user

    # Bad login/password?
    if ! logged_in?
      flash.now[:error] = 'Invalid user name or password.'
      Kernel.sleep 3 # Annoying, as it blocks the instance for other users too. Sigh.

      respond_to do |format|
        format.html { render :action => 'new' }
        format.json { render :nothing => true, :status  => 401 }
        format.xml  { render :nothing => true, :status  => 401 }
      end
      return
    end

    # Check if the user or the portal is locked
    locked_message  = account_or_portal_locked?(portal)
    if !locked_message.blank?
      flash[:error] = locked_message
      respond_to do |format|
        format.html { render :action => 'new' }
        format.json { render :nothing => true, :status  => 401 }
        format.xml  { render :nothing => true, :status  => 401 }
      end
      return
    end

    # Everything OK
    user_tracking(portal)

    respond_to do |format|
      format.html { redirect_back_or_default(start_page_path) }
      format.json { render :json => {:session_id => request.session_options[:id], :user_id => current_user.id}, :status => 200 }
      format.xml  { render :nothing => true, :status  => 200 }
    end

  end

  def account_or_portal_locked?(portal) #:nodoc:

    # Account locked?
    if self.current_user.account_locked?
      self.current_user = nil
      return "This account is locked, please write to #{User.admin.email || "the support staff"} to get this account unlocked."
    end

    # Portal locked?
    if portal.portal_locked? && !current_user.has_role?(:admin_user)
      self.current_user = nil
      return "The system is currently locked. Please try again later."
    end

    return ""
  end

  def user_tracking(portal) #:nodoc:
    current_session.activate
    #if params[:remember_me] == "1"
    #  current_user.remember_me unless current_user.remember_token?
    #  cookies[:auth_token] = { :value => self.current_user.remember_token , :expires => self.current_user.remember_token_expires_at }
    #end

    current_session.load_preferences_for_user(current_user)

    # Record the best guess for browser's remote host name
    reqenv  = request.env
    from_ip = reqenv['HTTP_X_FORWARDED_FOR'] || reqenv['HTTP_X_REAL_IP'] || reqenv['REMOTE_ADDR']
    if from_ip
      if from_ip  =~ /^[\d\.]+$/
        addrinfo  = Socket.gethostbyaddr(from_ip.split(/\./).map(&:to_i).pack("CCCC")) rescue [ from_ip ]
        from_host = addrinfo[0]
      else
        from_host = from_ip # already got name?!?
      end
    else
       from_ip   = '0.0.0.0'
       from_host = 'unknown'
    end
    current_session[:guessed_remote_ip]   = from_ip
    current_session[:guessed_remote_host] = from_host

    # Record the user agent
    raw_agent = reqenv['HTTP_USER_AGENT'] || 'unknown/unknown'
    current_session[:raw_user_agent]      = raw_agent

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
    current_user.addlog("Logged in from #{pretty_host} using #{pretty_brow}")
    portal.addlog("User #{current_user.login} logged in from #{pretty_host} using #{pretty_brow}")

    if current_user.has_role?(:admin_user)
      current_session[:active_group_id] = "all"
    end
  end

end
