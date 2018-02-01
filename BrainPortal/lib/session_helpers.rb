
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
    return nil unless session[:active_group_id]
    return nil if     session[:active_group_id] == "all"

    if !@current_project || @current_project.id.to_i != session[:active_group_id].to_i
      @current_project = Group.find_by_id(session[:active_group_id])
      session[:active_group_id] = nil if @current_project.nil?
    end

    @current_project
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
    large_info = CbrainSession.session_model.where(
      :session_id => @cbrain_api_token,
      :active     => true,
    ).where( "updated_at > ?", SESSION_API_TOKEN_VALIDITY.ago ).first
    return nil unless large_info
    CbrainSession.new(large_info)
  end

end

