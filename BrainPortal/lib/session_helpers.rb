
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
    end
  end

  # Returns the current session as a CbrainSession object.
  def cbrain_session
    @cbrain_session ||= CbrainSession.new(session)
  end

#TODO remove this method after fixing all calls to it; they need to be replaced by
# called to either session() (small data) or cbrain_session() (long data)
  def current_session
    puts_red "DEPRECATED: current_session() Instead use session(), or cbrain_session(). Ask Pierre."
    puts_red "AT: #{caller[0]}"
    cbrain_session
  end

  # Returns currently active project.
  def current_project
    return nil unless cbrain_session[:active_group_id]
    return nil if     cbrain_session[:active_group_id] == "all"

    if !@current_project || @current_project.id.to_i != cbrain_session[:active_group_id].to_i
      @current_project = Group.find_by_id(cbrain_session[:active_group_id])
      cbrain_session[:active_group_id] = nil if @current_project.nil?
    end

    @current_project
  end

end

