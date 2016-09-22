
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

# Sesssions controller for the BrainPortal interface
# This controller handles the login/logout function of the site.
#
# Original author: restful_authentication plugin
# Modified by: Tarek Sherif
class SessionsController < ApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  before_filter :user_already_logged_in, :only => [:new, :create]

  api_available

  def new #:nodoc:
    reqenv           = request.env
    rawua            = reqenv['HTTP_USER_AGENT'] || 'unknown/unknown'
    ua               = HttpUserAgent.new(rawua)
    @browser_name    = ua.browser_name    || "(unknown browser name)"
    @browser_version = ua.browser_version || "(unknown browser version)"

    respond_to do |format|
      format.html
      format.xml  { render :xml  => { :authenticity_token => form_authenticity_token } }
      format.json { render :json => { :authenticity_token => form_authenticity_token } }
      format.txt
    end
  end

  def create #:nodoc:
    # If the csrf token is blank, it was reset by Rails' request forgery protection
    # and we want to prevent login
    user = current_session["_csrf_token"].presence && User.authenticate(params[:login], params[:password]) # can be nil if it fails
    create_from_user(user)
  end

  def show #:nodoc:
    if current_user
      respond_to do |format|
        format.html { render :nothing => true,                            :status => 200 }
        format.xml  { render :xml     => { :user_id => current_user.id }, :status => 200 }
        format.json { render :json    => { :user_id => current_user.id }, :status => 200 }
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
    current_session.clear
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
  # Private methods
  #
  ###############################################

  private

  def user_already_logged_in #:nodoc:
    if current_user
      redirect_to start_page_path
    end
  end

  # Does all sort of housekeeping and checks when +user+ logs in.
  # If user is nil, tells the framework the authentication has failed.
  def create_from_user(user) #:nodoc:

    # Bad login/password?
    unless user
      flash.now[:error] = 'Invalid user name or password.'
      Kernel.sleep 3 # Annoying, as it blocks the instance for other users too. Sigh.
      self.current_user = nil
      auth_failed
      return
    end

    # Not in IP whitelist?
    whitelist = (user.meta[:ip_whitelist] || '')
      .split(',')
      .map { |ip| IPAddr.new(ip.strip) rescue nil }
      .reject(&:blank?)
    if whitelist.present? && ! whitelist.any? { |ip| ip.include? request.remote_ip }
      flash.now[:error] = 'Untrusted source IP address.'
      self.current_user = nil
      auth_failed
      return
    end

    self.current_user = user
    portal = BrainPortal.current_resource

    # Check if the user or the portal is locked
    locked_message  = portal_or_account_locked?(portal)
    if !locked_message.blank?
      flash[:error] = locked_message
      auth_failed
      return
    end

    # Everything OK
    user_tracking(portal) # Figures out IP address, user agent, etc, once.

    respond_to do |format|
      format.html { redirect_back_or_default(start_page_path) }
      format.json { render :json => {:session_id => request.session_options[:id], :user_id => current_user.id}, :status => 200 }
      format.xml  { render :nothing => true, :status  => 200 }
    end

  end

  # Send a proper HTTP error code
  # when a user has not properly authenticated
  def auth_failed
    respond_to do |format|
      format.html { render :action => 'new' }
      format.json { render :nothing => true, :status  => 401 }
      format.xml  { render :nothing => true, :status  => 401 }
    end
  end

  def portal_or_account_locked?(portal) #:nodoc:

    # Portal locked?
    if portal.portal_locked? && !current_user.has_role?(:admin_user)
      self.current_user = nil
      return "The system is currently locked. Please try again later."
    end

    # Account locked?
    if self.current_user.account_locked?
      self.current_user = nil
      return "This account is locked, please write to #{User.admin.email.presence || "the support staff"} to get this account unlocked."
    end

    return ""
  end

  def user_tracking(portal) #:nodoc:
    current_session.activate
    user   = current_user

    # Record the best guess for browser's remote host name
    reqenv  = request.env
    from_ip = reqenv['HTTP_X_FORWARDED_FOR'] || reqenv['HTTP_X_REAL_IP'] || reqenv['REMOTE_ADDR']
    if from_ip
      if from_ip  =~ /\A[\d\.]+\z/
        addrinfo  = Rails.cache.fetch("host_addr/#{from_ip}") do
          Socket.gethostbyaddr(from_ip.split(/\./).map(&:to_i).pack("CCCC")) rescue [ from_ip ]
        end
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

    # The authentication_mechanism is a string which describes
    # the mechanism that was used by the user to log in.
    authentication_mechanism = "password" # in future this could change
    user.addlog("Logged in with #{authentication_mechanism} from #{pretty_host} using #{pretty_brow}")
    portal.addlog("User #{user.login} logged in with #{authentication_mechanism} from #{pretty_host} using #{pretty_brow}")
    user.update_attribute(:last_connected_at, Time.now)

    # Admin users start with some differences in behavior
    if user.has_role?(:admin_user)
      current_session[:active_group_id] = "all"
    end
  end

end
