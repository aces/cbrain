
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

# Model representing a user with administrative rights.
# Admin users are meant to have access to all parts of the system.
class AdminUser < User

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def available_tools  #:nodoc:
    Tool.where(nil)
  end

  # List of groups which provide view access to resources.
  # It is possible for the user not to be a member of one of those groups.
  def viewable_groups
    Group.where(nil)
  end

  # List of groups that the user can assign to resources.
  # The user must be a member of one of these groups. Subset
  # of viewable_groups
  def assignable_groups
    Group.where(nil)
  end

  # List of groups that the user can modify (the group's attributes themselves, not the resources)
  def editable_groups
    Group.where(nil)
  end

  def available_tasks  #:nodoc:
    CbrainTask.where(nil)
  end

  def available_users  #:nodoc:
    User.where(nil)
  end

  def accessible_sites #:nodoc:
    Site.where(nil)
  end

  def visible_users #:nodoc:
    User.where(nil)
  end

end
