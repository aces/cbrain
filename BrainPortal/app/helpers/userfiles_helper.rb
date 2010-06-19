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
  
  # Creates a link to the edit page of a +userfile+, as long
  # as the +user+ has access to it. By default, +user+ is
  # current_user.
  #
  # +userfile+ can be provided as an ID too.
  #
  # If the ID is nil, then the string
  #   "(None)"
  # will be returned.
  #
  # If the ID is invalid, the string
  #   "(Deleted/Non-existing file)"
  # will be returned.
  #
  # +options+ can contain a :name for
  # the link (the default is the userfile's name) and a
  # :path (the default is the edit path).
  def link_to_userfile_if_accessible(userfile, user = current_user, options = {})
    return "(None)" if userfile.blank?
    unless userfile.is_a?(Userfile)
      userfile = Userfile.find(userfile) rescue nil
      return "(Deleted/Non-existing file)" if userfile.blank?
    end
    name = options[:name] || userfile.name
    path = options[:path] || edit_userfile_path(userfile)
    if userfile.available? && userfile.can_be_accessed_by?(user)
      link_to(name, path)
    else
      name
    end
  end
  
  #Create a link for object files in a civet collection
  def obj_link(file_name, userfile)
    display_name = file_name.sub(/^.+\/surfaces\//, "")
    if userfile.is_locally_synced? && file_name[-4, 4] == ".obj"
      link_to display_name, "#", "data-content-url" => url_for(:controller  => :userfiles, :id  => userfile.id, :action  => :content, :collection_file  => file_name), 
                                 "class"  => "o3d_link"
    else
      display_name
    end
  end
  
  def userfiles_menu_option(name, option_name, partial) #:nodoc:
    link_to_function name, {:class => " button userfile_menu", :id  => option_name}  do |page|
      page << "if(current_options != '#{option_name}'){"
      page << "var local_var = current_options;"
      page[option_name].visual_effect(:morph, :style  => 'background-color: #FFFFFF; color: ##0073ea', :duration  => 0.4)
      page << "if(local_var){Element.hide(local_var + '_div');"
      page << "new Effect.Morph(local_var, {style: 'background-color: #ffffff; #0073ea;', duration: 0.2});"
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
      page << "new Effect.Morph(current_options, {style: 'background-color: #ffffff; #0073ea', duration: 0.2});"
      page << "Element.hide(current_options + '_div');"
      page << "Element.update(current_options + '_div', '');"
      page << "current_options = null;"
    end +
    '</div>'
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
  
  #Display the contents o.f a file to a view (meaning of contents depends on the type of file,
  #e.g. images, text, xml)
  def display_contents(userfile)
    before_content = '<div id="userfile_contents_display">'
    before_content += link_to_function '<strong>Contents</strong>' do |page|
      page[:userfile_contents_display_toggle].toggle
    end
    
    content = ""
    after_content = '</div>'
    
    if userfile.is_a? CivetCollection
       clasp_file  = userfile.list_files.find { |f| f.name =~ /clasp\.png$/ }
       verify_file = userfile.list_files.find { |f| f.name =~ /verify\.png$/}
       if clasp_file
         content =  "<h3>Clasp</h3>"
         content += image_tag url_for(:action  => :content, :collection_file  => clasp_file.name)
       end
       
       if verify_file
         content += "<br><h3>Verify</h3>"
         content += image_tag url_for(:action  => :content, :collection_file  => verify_file.name)
       end
    else
      file_name = userfile.name
      case file_name
      when /(\.txt|\.xml|\.log)$/
        content = '<PRE>' + h(File.read(userfile.cache_full_path)) + '</PRE>'
      when /(\.jpe?g|\.gif|\.png)$/
        content = image_tag "/userfiles/#{userfile.id}/content#{$1}"
      end
    end
    
    if content.blank? 
      before_content = ""
      content = ""
      after_content = ""
    else
      content = '<div id="userfile_contents_display_toggle" style="display:none"><BR><BR>' + content + '</div>'
    end
    
    before_content + content + after_content
  end
end
