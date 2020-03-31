
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
    available_group_ids    = (self.public_and_available_groups.pluck(:id) + self.group_ids).uniq
    available_bourreau_ids = Bourreau.find_all_accessible_by_user(self).pluck(:id)


    tools = Tool.where( ["tools.user_id = ? OR tools.group_id IN (?)", self.id, available_group_ids ])
    tools = tools.joins(:tool_configs).where(["tool_configs.bourreau_id IN (?)",available_bourreau_ids]).group('tools.id')

    tools
  end

  def available_groups  #:nodoc:
    self.groups.where("groups.type <> 'EveryoneGroup'").where(:invisible => false)
  end

  def public_and_available_groups
    group_scope = Group.where(["groups.id IN (?)",self.group_ids]).or(Group.where(:public => true))
    group_scope = group_scope.where("groups.type <> 'EveryoneGroup'").where(:invisible => false)

    group_scope
  end

  def available_tasks  #:nodoc:
    available_group_ids    = self.public_and_available_groups.pluck(:id)
    tasks = CbrainTask.where( ["cbrain_tasks.user_id = ? OR cbrain_tasks.group_id IN (?)", self.id, available_group_ids] )

    available_bourreau_ids = Bourreau.find_all_accessible_by_user(self).pluck(:id)
    tasks = tasks.where(:bourreau_id => available_bourreau_ids)
    tasks
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
