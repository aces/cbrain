
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
    Tool.where( ["tools.user_id = ? OR tools.group_id IN (?)", self.id, self.group_ids])
  end

  def available_groups  #:nodoc:
    self.groups.where("groups.type <> 'EveryoneGroup'").where(:invisible => false)
  end

  def available_tasks  #:nodoc:
    CbrainTask.where( ["cbrain_tasks.user_id = ? OR cbrain_tasks.group_id IN (?)", self.id, self.group_ids] )
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
