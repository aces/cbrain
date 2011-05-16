
#
# CBRAIN Project
#
# Group model
#
# Original author: Tarek Sherif
#
# $Id$
#

#This model represents an group created for the purpose of assigning collective permission
#to resources (as opposed to SystemGroup). 
class WorkGroup < Group

  Revision_info="$Id$"
  
  def pretty_category_name(as_user)
    if self.users.size == 1
      return 'My Work Project' if self.users[0].id == as_user.id
      return "Personal Work Project of #{self.users[0].login}"
    end
    return 'Shared Work Project'
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

