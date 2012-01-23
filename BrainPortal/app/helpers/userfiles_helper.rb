#Helper methods for Userfile views.
module UserfilesHelper

  Revision_info=CbrainFileRevision[__FILE__]
  
  # For display of userfile names, including: 
  # type icon (collection or file), parentage icon,
  # link to show page, sync status and formats.
  def filename_listing(userfile, link_options={})
    html = []
    html << tree_view_icon(@filter_params["tree_sort"] == "on", userfile.level) if (userfile.level || 0) > 0
    if userfile.is_a? FileCollection
      file_icon = image_tag "/images/folder_icon_solid.png"
    else
      file_icon = image_tag "/images/file_icon.png"
    end
    html << ajax_link(file_icon, {:action => :index, :clear_filter => true, :find_file_id => userfile.id}, :datatype => "script", :title => "Show in Unfiltered File List")
    html << " "
    html << link_to_userfile_if_accessible(userfile, nil, link_options)
    userfile.sync_status.each do |syncstat| 
      html << render(:partial => 'userfiles/syncstatus', :locals => { :syncstat => syncstat })
    end 
    if userfile.formats.size > 0 
      html << "<br>"
      html << ("&nbsp;" * ((userfile.level || 0) * 5))
      html << show_hide_toggle("Formats ", ".format_#{userfile.id}", :class  => "action_link")
      html << userfile.formats.map do |u| 
                if u.available?
                  cb = check_box_tag("file_ids[]", u.id.to_s, false)
                else
                  cb = "<input type='checkbox' DISABLED />"
                end
                cb = "<span class=\"format_#{userfile.id}\" style=\"display:none\">#{cb}</span>"
                link_to_userfile_if_accessible(u,current_user,:name => u.format_name) + " #{cb}".html_safe
              end.join(", ")
    end
    html.join.html_safe
  end
  
  def shift_file_link(userfile, dir, same_type, options = {})
    if dir.to_s.downcase == "previous"
      direction = "previous"
    else
      direction = "next"
    end
    
    link_options = options.delete(:html)
    options[:conditions] ||= {}
    
    if current_project && !(options[:conditions].has_key?(:group_id) || options[:conditions].has_key?("userfiles.group_id"))
      options[:conditions]["userfiles.group_id"] = current_project.id
    end
    
    if same_type
      options[:conditions]["userfiles.type"] = userfile.class.name
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
    (
    "<div class=\"display_table\" style=\"width:100%\">" +
      "<div class=\"display_row\">" +
        "<div class=\"display_cell\">#{previous_file_link(@userfile, options.clone)}</div><div class=\"display_cell\" style=\"text-align:right\">#{next_file_link(@userfile, options.clone)}</div>" + 
      "</div>" +
      "<div class=\"display_row\">" +
        "<div class=\"display_cell\">#{previous_typed_file_link(@userfile, options.clone)}</div><div class=\"display_cell\" style=\"text-align:right\">#{next_typed_file_link(@userfile, options.clone)}</div>" +
      "</div>" +
    "</div>"
    ).html_safe
  end
  
  def data_link(file_name, userfile)
    display_name = Pathname.new(file_name).basename.to_s
    matched_class = SingleFile.descendants.unshift(SingleFile).find{ |c| file_name =~ c.file_name_pattern }
    if matched_class && userfile.is_locally_synced?
      if matched_class <= TextFile
        link_to h(display_name), url_for(:controller  => :userfiles, :id  => userfile.id, :action  => :display, :content_loader => :collection_file, :arguments => file_name, :viewer => "text_file", :content_viewer => "off"),
                                 :target => "_blank"
      elsif matched_class <= ImageFile
        link_to h(display_name), url_for(:controller  => :userfiles, :id  => userfile.id, :action  => :display, :content_loader => :collection_file, :arguments => file_name, :viewer => "image_file", :content_viewer => "off"),
                                 :target => "_blank"
      else
         h(display_name)
      end
    else
      h(display_name)
    end
  end
  
  # Return the HTML code that represent a symbol
  # for +statkeyword+, which is a SyncStatus 'status'
  # keyword. E.g. for "InSync", the
  # HTML returned is a green checkmark, and for
  # "Corrupted" it's a red 'x'.
  def status_html_symbol(statkeyword)
    html = case statkeyword
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
    html.html_safe
  end
  
  #Create a collapsable "Content" box for userfiles show page.
  def content_viewer(&block)
    safe_concat('<div id="userfile_contents_display">')
    safe_concat(show_hide_toggle '<strong>Displayable Contents</strong>', "#userfile_contents_display_toggle")
    safe_concat('<div id="userfile_contents_display_toggle" style="display:none"><BR><BR>')
    safe_concat(capture(&block))
    safe_concat('</div>')
    safe_concat('</div>')
    ""
  end
  
end
