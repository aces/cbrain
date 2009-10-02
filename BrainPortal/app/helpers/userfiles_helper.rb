#Helper methods for Userfile views.
module UserfilesHelper

  Revision_info="$Id$"

  #Alternate toggle for session attributes that switch between values 'on' and 'off'.
  def set_toggle(old_value)
   old_value == 'on' ? 'off' : 'on'
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
  
  def userfiles_menu_close_button
    '<div class="userfiles_option_close">' +
    link_to_function('close', :class  => 'action_link') do |page|
      page << "new Effect.Morph(current_options, {style: 'background-color: #0471B4; color:#F8F8F8;', duration: 0.2});"
      page << "Element.hide(current_options + '_div');"
      page << "Element.update(current_options + '_div', '');"
      page << "current_options = null;"
    end +
    '</div>'
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
