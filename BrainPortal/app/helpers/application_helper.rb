require 'time'

#Helper methods for all views.
module ApplicationHelper

  Revision_info="$Id$"

  #################################################################################
  # Layout Helpers
  #################################################################################
  
  #Sets the text to be displayed in the title bar when a given view is rendered.
  def title(page_title)
    content_for(:title)  { ' - ' + page_title }
  end

  def add_tool_tip(message, element='span', &block)
    content = capture(&block)
    
    if message.blank?
      concat(content)
      return
    end
    concat("<#{element} title='#{message}'>")
    concat(content)
    concat("</#{element}>")
  end
 
  def string_if(condition, content)
    if condition
      content
    else
      ""
    end
  end

  # This method reformats a long SSH key text so that it
  # is folded on several lines.
  def pretty_ssh_key(ssh_key)
     return "(None)" if ssh_key.blank?
     return ssh_key
     #pretty = ""
     #while ssh_key != ""
     #  pretty += ssh_key[0,200] + "\n"
     #  ssh_key[0,200] = ""
     #end
     #pretty
  end
  
  def set_selected(param_controller, current_item)
    if(current_item == :user_site_show && 
      params[:controller].to_s == 'sites' &&
      params[:action].to_s == 'show' &&
      params[:id].to_s == current_user.site_id.to_s)
      'id="selected"'
    elsif(param_controller.to_s == current_item.to_s)
      'id="selected"'
    else
      'id="unselected"'
    end
  end

  #Reduces a string to the length specified by +length+.
  def crop_text_to(length, string)
    return ""     if string.blank?
    return string if string.length <= length
    return string[0,length-3] + "..."
  end

  # Produces a pretty 'delete' symbol (used mostly for removing
  # active filters)
  def delete_icon
    "&nbsp;<span style=\"color:red;text-decoration:none;\">&otimes;</span>&nbsp;"
  end

  #################################################################################
  # Resource Listing Helpers
  #################################################################################
  
  #Set direction for resource list sorting
  def set_dir_old(current_order, prev_order, sort_order)
    if(current_order.to_s == prev_order.to_s)
      sort_order == 'DESC' ? '' : 'DESC'
    end
  end
  
  #Set direction for resource list sorting
  def set_dir(current_order, sort_params)
    return unless sort_params
    prev_order = sort_params["order"]
    sort_order = sort_params["dir"]
    
    if(current_order.to_s == prev_order.to_s)
      sort_order == 'DESC' ? '' : 'DESC'
    end
  end
  
  #Set arrow icon for ordering of userfiles. I.e. display a red arrow
  #next to the header of a given column in the Userfile index table *if*
  #that column is the one currently determining the order of the file.
  #
  #Toggles the direction of the arrow depending on whether the order is 
  #ascending or descending.
  def set_order_icon(location, current_order, current_dir = nil)
    return "" if current_order == nil
    
    #order, direction = session_order.sub("type, ", "").split
    
    return "" unless location == current_order
    
    if location == 'tree_sort' || location == 'cbrain_tasks.launch_time DESC, cbrain_tasks.created_at'
      icon = '<font color="Red">&nbsp;&bull;</font>'
    else
      icon = '<font color="Red">&nbsp;&dArr;</font>'
      if current_dir == 'DESC'
        icon = '<font color="Red">&nbsp;&uArr;</font>'
      end
    end
    
    icon || ""
  end
end
