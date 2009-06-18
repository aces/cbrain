module UserfilesHelper

  Revision_info="$Id$"

  def set_toggle(old_value)
   old_value == 'on' ? 'off' : 'on'
  end
  
  def set_order_icon(location, session_order)
    order, direction = session_order.sub("type, ", "").split
    
    return unless location == order
    
    icon = '<font color="Red">&nbsp;&dArr;</font>'
    
    if direction == 'DESC'
      icon = '<font color="Red">&nbsp;&uArr;</font>'
    end
    
    icon
  end
  
  def tree_view_icon(order, level)
    if order == 'lft'
      '&nbsp' * 4 * level + '&#x21b3;'
    end
  end
end
