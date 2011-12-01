# Basic view helpers. Mainly text manipulation and icons.
module BasicHelper
  
  Revision_info=CbrainFileRevision[__FILE__]
  
  #Sets the text to be displayed in the title bar when a given view is rendered.
  def title(page_title)
    content_for(:title)  { ' - ' + page_title }
  end
  
  # Add a tooltip to a block of html
  def add_tool_tip(message, element='span', &block)
    content = capture(&block)
    
    if message.blank?
      safe_concat(content)
      return
    end
    safe_concat("<#{element} title='#{message}'>")
    safe_concat(content)
    safe_concat("</#{element}>")
  end
 
  # Return +content+ only if condition evaluates to true.
  def string_if(condition, content)
    if condition
      content
    else
      ""
    end
  end
  
  # Sets which of the menu tabs at the top of the page is 
  # selected.
  def set_selected(param_controller, current_item)
    if(current_item == :user_site_show && 
      params[:controller].to_s == 'sites' &&
      params[:action].to_s == 'show' &&
      params[:id].to_s == current_user.site_id.to_s)
      'class="selected"'.html_safe
    elsif(param_controller.to_s == current_item.to_s)
      'class="selected"'.html_safe
    else
      'class="unselected"'.html_safe
    end
  end

  #Reduces a string to the length specified by +length+.
  def crop_text_to(length, string)
    return ""     if string.blank?
    return h(string) if string.length <= length
    return h(string[0,length-3]) + "...".html_safe
  end

  # Produces a pretty 'delete' symbol (used mostly for removing
  # active filters)
  def delete_icon
    "&nbsp;<span class=\"delete_icon\">&otimes;</span>&nbsp;".html_safe
  end
  
end

