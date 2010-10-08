#Helper methods for Userfile views.
module UserfilesHelper

  Revision_info="$Id$"

  #Alternate toggle for session attributes that switch between values 'on' and 'off'.
  def set_toggle(old_value)
   old_value == 'on' ? 'off' : 'on'
  end
  
  #Indents children files in the Userfile index table *if* the 
  #current ordering is 'tree view'.
  def tree_view_icon(tree_sort, level)
    if tree_sort == 'on'
      '&nbsp' * 4 * level + '&#x21b3;'
    end
  end
  
  def shift_file_link(userfile, dir, same_type, link_options = {})
    if dir.to_s.downcase == "previous"
      direction = "previous"
    else
      direction = "next"
    end
    
    options = {}
    options[:conditions] = {}

    options[:access_requested] = link_options.delete(:access_requested) || :write
    
    if current_project
      options[:conditions][:group_id] = current_project.id
    end
    
    if same_type
      options[:conditions][:type] = userfile.class.name
      text = "#{direction.capitalize} #{userfile.class.name}"
    else
      text = "#{direction.capitalize} File"
    end
    
    if direction == "previous"
      text = "<< " + text
    else
      text += " >>"
    end
    
    file = userfile.send("#{direction}_available_file", current_user, options)
    
    action = params[:action] #Should be show or edit.
    
    
    if file
      link_to text, {:action  => action, :id  => file.id}, link_options
    else
      ""
    end  
  end
  
  def next_file_link(userfile, options = {})
    shift_file_link(userfile, :next, false, options)
  end
  
  def previous_file_link(userfile, options = {})
    shift_file_link(userfile, :previous, false, options)
  end
  
  def next_typed_file_link(userfile, options = {})
    shift_file_link(userfile, :next, true, options)
  end
  
  def previous_typed_file_link(userfile, options = {})
    shift_file_link(userfile, :previous, true, options)
  end
  
  def file_link_table(userfile, options = {})
    "<div class=\"display_table\" style=\"width:100%\">" +
      "<div class=\"display_row\">" +
        "<div class=\"display_cell\">#{previous_file_link(@userfile, options.clone)}</div><div class=\"display_cell\" style=\"text-align:right\">#{next_file_link(@userfile, options.clone)}</div>" + 
      "</div>" +
      "<div class=\"display_row\">" +
        "<div class=\"display_cell\">#{previous_typed_file_link(@userfile, options.clone)}</div><div class=\"display_cell\" style=\"text-align:right\">#{next_typed_file_link(@userfile, options.clone)}</div>" +
      "</div>" +
    "</div>"
  end
  
  #Create a link for object files in a civet collection
  def obj_link(file_name, userfile)
    display_name = file_name.sub(/^.+\/surfaces\//, "")
    if userfile.is_locally_synced? && file_name[-4, 4] == ".obj"
      link_to display_name, "#", "data-content-url" => url_for(:controller  => :userfiles, :id  => userfile.id, :action  => :content, :collection_file  => file_name), "data-content" => url_for(:controller  => :userfiles, :id  => userfile.id, :action  => :content),
      "class"  => "o3d_link", "data-viewer" =>  "#{display_userfile_path(userfile, :viewer  => "civet_collection/obj_viewer", :apply_div  => false, :collection_file  => file_name)}"
    else
      display_name
    end
  end
  
  # Return the HTML code that represent a symbol
  # for +statkeyword+, which is a SyncStatus 'status'
  # keyword. E.g. for "InSync", the
  # HTML returned is a green checkmark, and for
  # "Corrupted" it's a red 'x'.
  def status_html_symbol(statkeyword)
    case statkeyword
      when "InSync"
        '<font color="green">&#10003;</font>'
      when "ProvNewer"
        '<font color="green">&lowast;</font>'
      when "CacheNewer"
        '<font color="purple">&there4;</font>'
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
  
  #Create a collapsable "Content" box for userfiles show page.
  def content_viewer(&block)
    concat('<div id="userfile_contents_display">')
    concat(show_hide_toggle '<strong>Contents</strong>', "#userfile_contents_display_toggle")
    concat('<div id="userfile_contents_display_toggle" style="display:none"><BR><BR>')
    concat(capture(&block))
    concat('</div>')
    concat('</div>')
  end
  
end
