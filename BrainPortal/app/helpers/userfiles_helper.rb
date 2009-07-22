#Helper methods for Userfile views.
module UserfilesHelper

  Revision_info="$Id$"

  #Alternate toggle for session attributes that switch between values 'on' and 'off'.
  def set_toggle(old_value)
   old_value == 'on' ? 'off' : 'on'
  end
  
  #Set arrow icon for ordering of userfiles. I.e. display a red arrow
  #next to the header of a given column in the Userfile index table *if*
  #that column is the one currently determining the order of the file.
  #
  #Toggles the direction of the arrow depending on whether the order is 
  #ascending or descending.
  def set_order_icon(location, session_order)
    order, direction = session_order.sub("type, ", "").split
    
    return unless location == order
    
    icon = '<font color="Red">&nbsp;&dArr;</font>'
    
    if direction == 'DESC'
      icon = '<font color="Red">&nbsp;&uArr;</font>'
    end
    
    icon
  end
  
  #Indents children files in the Userfile index table *if* the 
  #current ordering is 'tree view'.
  def tree_view_icon(order, level)
    if order == 'lft'
      '&nbsp' * 4 * level + '&#x21b3;'
    end
  end
  
  #Creates a link labeled +name+ to the url +path+ *if* *and* *only* *if*
  #the current user has a role of *admin*. Otherwise, +name+ will be 
  #displayed as static text.
  def link_if_accessible(name, path, userfile, user)
    if userfile.can_be_accessed_by?(user) || true
      link_to(name, path)
    else
      name
    end
  end
  
end
