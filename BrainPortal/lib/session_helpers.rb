
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

# Helpers to handle session
module SessionHelpers

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  SESSION_API_TOKEN_VALIDITY = 1.day #:nodoc: How long a token is valid if not used.

  def self.included(includer) #:nodoc:
    includer.class_eval do
      helper_method :current_project, :cbrain_session
    end
  end

  # Returns the current session as a CbrainSession object.
  def cbrain_session
    @cbrain_session ||= cbrain_session_from_api_token
    @cbrain_session ||= CbrainSession.new(session) # A new wrapper
  end

  # Returns currently active project.
  def current_project
    return nil unless cbrain_session[:active_group_id].present?
    return nil if     cbrain_session[:active_group_id] == "all"

    if !@current_project || @current_project.id.to_i != cbrain_session[:active_group_id].to_i
      @current_project = Group.find_by_id(cbrain_session[:active_group_id])
      cbrain_session[:active_group_id] = nil if @current_project.nil?
    end

    @current_project
  end

  # return currently active project if user can assign to
  def current_assignable_project_id
    return current_project.id && current_user.assignable_group_ids.include?(current_project.id)
  end

  private

  # For API calls. A +cbrain_api_token+ is expected in the params.
  # For the moment, the API token is the same as a standard session_id, even though
  # we don't send/receive the session object using cookies. The token will
  # be used to look up a LargeSessionInfo object (the class returned by
  # CbrainSession.session_model). This will have been created
  # during the initial login of the API. If we can find it and it's valid,
  # it means the cbrain_session must be associated with it. The LargeSessionInfo
  # object will also provide us later with the associated user account.
  def cbrain_session_from_api_token
    return nil unless @cbrain_api_token

    # 1) We must find a record for the session in LargeSessionInfo table:
    large_info = CbrainSession.session_model.where(
      :session_id => @cbrain_api_token,
      :active     => true,
    ).where( "updated_at > ?", SESSION_API_TOKEN_VALIDITY.ago ).first
    return nil unless large_info

    # 2) Make sure the current request's IP matches the IP
    # recorded when login/password was first sent
    orig_ip   = large_info.data[:guessed_remote_ip]
    # The method cbrain_request_remote_ip comes from RequestHelpers module
    remote_ip = cbrain_request_remote_ip rescue "UnknownIP-#{rand(1000000)}"

    # If orig_ip is blank, it's probably the first use of
    # this token, so we we can handle some stuff here.
    # Note: a callback in ApplicationController will set
    # the values for :guessed_remote_ip and :guessed_remote_host
    if orig_ip.blank?
      # Record the current user agent
      large_info.data[:orig_raw_user_agent] = large_info.data[:raw_user_agent] if large_info.data[:raw_user_agent]
      reqenv    = request.env || {}
      raw_agent = reqenv['HTTP_USER_AGENT'] || 'unknown/unknown'
      large_info.data[:raw_user_agent] = raw_agent
    end

    # If they differ, log and invalidate the session
    if orig_ip.present? && orig_ip != remote_ip
      # Log the error in many places
      user = large_info.user
      userlogin = user.try(:login) || 'Unknown'
      message = "API token has changed IP address: user=#{userlogin}, orig=#{orig_ip}, current=#{remote_ip}"
      Rails.logger.error message
      user.addlog(message) if user
      # Clean up
      large_info.active = false # deactivate
      large_info.save
      # Token is invalid!
      return nil
    end

    # 3) Build and return CbrainSession wrapper around the LargeSessionInfo object
    CbrainSession.new(large_info)
  end

end

