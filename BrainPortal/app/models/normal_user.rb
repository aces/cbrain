
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

# Model representing a user with normal rights.
# Normal users only have access to resources they own or those
# of projects they are members of.
class NormalUser < User

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def available_tools  #:nodoc:
    Tool.where( ["tools.user_id = ? OR tools.group_id IN (?)", self.id, self.viewable_group_ids ])
  end

  # List of groups which provide view access to resources.
  # It is possible for the user not to be a member of one of those groups.
  def viewable_groups
    Group.where(:id => (self.group_ids + Group.public_group_ids))
  end

  # List of groups that the user can list in the interface. Normally, groups that are invisible
  # are not listed
  def listable_groups
    viewable_groups.where(:invisible => false).without_everyone
  end

  # List of groups that the user can assign to resources.
  # The user must be a member of one of these groups.
  # Removed from the list:
  #   the singleton EveryoneGroup
  #   groups that are marked as "not_assignable" (attribute)
  # Always on the list:
  #   groups that the user created themselves (creator_id == user.id)
  #   groups that the user is an editor
  def assignable_groups
    all_gids        = self.group_ids - [ Group.everyone.id ]
    assignable_gids = Group.where(:id => all_gids).where(:not_assignable => false).pluck(:id)
    creat_edit_gids = self.editable_group_ids + Group.where(:creator_id => self.id).pluck(:id)
    Group.where(:id => (assignable_gids | creat_edit_gids).uniq)
  end

  # List of groups that the user can modify (the group's attributes themselves, not the resources)
  def modifiable_groups
    WorkGroup.where(:creator_id => self.id).or(WorkGroup.where(:id => self.editable_group_ids))
  end

  def available_tasks  #:nodoc:
    CbrainTask.where( ["cbrain_tasks.user_id = ? OR cbrain_tasks.group_id IN (?)", self.id, viewable_group_ids] )
  end

  def available_users  #:nodoc:
    User.where( :id => self.id )
  end

  def accessible_sites #:nodoc:
    Site.where( :id => (self.site_id || -1) )
  end

  def visible_users #:nodoc:
    User.where("users.type <> 'AdminUser'")
  end

end
