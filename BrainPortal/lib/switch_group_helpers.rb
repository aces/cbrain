
#
# CBRAIN Project
#
# Copyright (C) 2021-2022
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

# Helpers for switching the current group (a state in the session).
#
# Used only in the Userfile and Group controllers.
module SwitchGroupHelpers

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Change the current group of the current user.
  # The argument group_id can be +nil+ or the string 'all', too.
  # Returns true if the group was switched, and false if
  # no change was performed.
  def switch_current_group(group_id)
    orig_active_group_id = cbrain_session[:active_group_id].presence

    if group_id.blank? # FIXME I am not sure what that means. Pierre May 2022
      cbrain_session[:active_group_id] = nil
      return orig_active_group_id.present?  # say if it was changed or not
    end

    if group_id == "all"
      cbrain_session[:active_group_id] = "all"
      return orig_active_group_id != "all" # changed or not
    end

    switchable_groups = current_user.listable_groups
    switchable_groups = switchable_groups.without_everyone if ! current_user.has_role? :admin_user
    new_group = switchable_groups.find(group_id)
    cbrain_session[:active_group_id] = new_group.id
    return orig_active_group_id != new_group.id
  end

  # This method will set a session flag that will tell the userfiles 'index' action
  # to add javscript code to the page to clear the persistently selected list of files.
  def trigger_unselect_of_all_persistent_files
    cbrain_session[:switched_active_group] = true
  end

  # This method removes any active column filters for selecting
  # a particular group for the userfiles and tasks index pages.
  def remove_group_filters_for_files_and_tasks
    ['userfiles#index', 'tasks#index'].each do |name|
      scope = scope_from_session(name)
      scope.filters.reject! { |f| f.attribute.to_s == 'group_id' }
      scope_to_session(scope, name)
    end
  end

end
