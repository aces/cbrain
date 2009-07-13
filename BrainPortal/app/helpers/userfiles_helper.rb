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
end
