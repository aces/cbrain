
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

# Model representing a user with site manager rights.
# Site managers are meant to have access to all resources relating to
# the site they manage.
class SiteManager < User

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  validates_presence_of :site_id, :message => "must be set for site managers"

  def available_tools  #:nodoc:
    Tool.where( ["tools.group_id IN (?) OR tools.user_id IN (?)", self.group_ids, self.site.user_ids])
  end

  def available_groups  #:nodoc:
    group_scope = Group.where(["groups.id IN (select groups_users.group_id from groups_users where groups_users.user_id=?) OR groups.site_id=?", self.id, self.site_id])
    group_scope = group_scope.where("groups.type <> 'EveryoneGroup'").where(:invisible => false)

    group_scope
  end

  def available_tasks  #:nodoc:
    CbrainTask.where( ["cbrain_tasks.group_id IN (?) OR cbrain_tasks.user_id IN (?)", self.group_ids, self.site.user_ids] )
  end

  def available_users  #:nodoc:
    self.site.users
  end

  def accessible_sites #:nodoc:
    Site.where( :id => self.site_id )
  end

  def visible_users #:nodoc:
    User.where("users.type <> 'AdminUser'")
  end

end
