
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

class NormalUser < User
  
  Revision_info=CbrainFileRevision[__FILE__]

  def available_tools  #:nodoc:
    Tool.where( ["tools.user_id = ? OR tools.group_id IN (?)", self.id, self.group_ids])
  end
  
  def available_groups  #:nodoc:              
    group_scope = self.groups.where("groups.name <> 'everyone'")
    group_scope = group_scope.where(["groups.type NOT IN (?)", InvisibleGroup.descendants.map(&:to_s).push("InvisibleGroup") ])
    
    group_scope
  end
  
  def available_tasks  #:nodoc:
    CbrainTask.where( ["cbrain_tasks.user_id = ? OR cbrain_tasks.group_id IN (?)", self.id, self.group_ids] )
  end
  
  def available_users  #:nodoc:
    User.where( :id => self.id )
  end
  
  def visible_users #:nodoc:
    if site
      site.users.where("users.type <> 'AdminUser'")
    else
      []
    end
  end
  
end
