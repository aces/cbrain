
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

  def self.included(includer) #:nodoc:
    includer.class_eval do
      helper_method :current_session,   :current_project
      before_filter :always_activate_session
    end
  end

  # Returns the current session as a CbrainSession object.
  def current_session
    @cbrain_session ||= CbrainSession.new(session, request.env['rack.session.record'] )
  end

  # Returns currently active project.
  def current_project
    return nil unless current_session[:active_group_id]
    return nil if current_session[:active_group_id] == "all"

    if !@current_project || @current_project.id.to_i != current_session[:active_group_id].to_i
      @current_project = Group.find_by_id(current_session[:active_group_id])
      current_session[:active_group_id] = nil if @current_project.nil?
    end

    @current_project
  end

  def always_activate_session #:nodoc:
    session[:cbrain_toggle] = (1 - (session[:cbrain_toggle] || 0))
    true
  end

end

