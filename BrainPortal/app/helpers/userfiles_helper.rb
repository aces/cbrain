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
    
    if location == 'userfiles.lft'
      icon = '<font color="Red">&nbsp;&bull;</font>'
    else
      icon = '<font color="Red">&nbsp;&dArr;</font>'
      if direction == 'DESC'
        icon = '<font color="Red">&nbsp;&uArr;</font>'
      end
    end
    
    icon
  end
  
  #Indents children files in the Userfile index table *if* the 
  #current ordering is 'tree view'.
  def tree_view_icon(order, level)
    if order == 'userfiles.lft'
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
  
  def userfiles_menu_option(name, option_name, partial)
    link_to_function name, {:class => "userfile_menu", :id  => option_name}  do |page|
      page << "if(current_options != '#{option_name}'){"
      page << "var local_var = current_options;"
      page[option_name].visual_effect(:morph, :style  => 'background-color: #FFFFFF; color: #000000', :duration  => 0.4)
      page << "if(local_var){Element.hide(local_var + '_div');"
      page << "new Effect.Morph(local_var, {style: 'background-color: #0471B4; color:#F8F8F8;', duration: 0.2});"
      page << "Element.update(local_var + '_div', '');"
      page << "}"
      page << "current_options = '#{option_name}';"
      page.replace_html(option_name + '_div', :partial  => partial)
      page[option_name + '_div'].visual_effect(:blind_down, :duration  => 0.4)
      page << "}"
    end
  end
  
  def userfiles_menu_remote_option(name, option_name, url, expected_response = :html)
    if(expected_response.to_sym == :html)
      update_location = option_name + '_div'
    else
      update_location = nil
    end
    link_to_remote  name,
                  {:url  => url,
                   :method  => 'get',
                   :condition  => "current_options != '#{option_name}'",
                   :before  => "if(current_options){new Effect.Morph(current_options, {style: 'background-color: #0471B4; color:#F8F8F8;', duration: 0.2});} $('upload_option').morph('background-color: #FFFFFF; color: #000000');",
                   :after  => "current_options = '#{option_name}';",
                   :update  => update_location,
                   :complete  => "if(current_options){Element.hide(current_options + '_div'); Element.update(current_options + '_div', ''););Element.update(current_options + '_div', '');} Effect.BlindDown('#{option_name + '_div'}', {duration: 0.4})"
                   },
                  {:class => "userfile_menu", :id  => 'upload_option'}
  end  

  def status_html_symbol(statkeyword)
    case statkeyword
      when "InSync"
        '<font color="green">&#10003;</font>'
      when "ProvNewer"
        '<font color="green">&lowast;</font>'
      when "CacheNewer"
        '<font color="yellow">&there4;</font>'
      when "ToCache"
        '<font color="blue">&darr;</font>'
      when "ToProvider"
        '<font color="blue">&uarr;</font>'
      when "Corrupted"
        '<font color="red">&times;</font>'
      else
        '<font color="red">?</font>'
    end
  end
end
