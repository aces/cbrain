
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

#This model represents an group created for the purpose of assigning collective permission
#to resources (as opposed to SystemGroup). 
class WorkGroup < Group

  Revision_info=CbrainFileRevision[__FILE__]
    
  def pretty_category_name(as_user)
    if self.users.size == 1
      return 'My Work Project' if self.users[0].id == as_user.id
      return "Personal Work Project of #{self.users[0].login}"
    end
    return 'Shared Work Project'
  end
  
  def short_pretty_type
    if self.users.count > 1
      return "Shared"
    else
      return ""
    end
  end
  
  def can_be_edited_by?(user)
    if user.has_role? :admin
      return true
    elsif user.has_role? :site_manager
      if self.site_id == user.site.id
        return true
      end
    end
    return self.users.size == 1 && self.users.first == user
  end

end

