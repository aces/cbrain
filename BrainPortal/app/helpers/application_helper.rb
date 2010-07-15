require 'time'

#Helper methods for all views.
module ApplicationHelper

  Revision_info="$Id$"

  #################################################################################
  # Layout Helpers
  #################################################################################
  
  #Sets the text to be displayed in the title bar when a given view is rendered.
  def title(page_title)
    content_for(:title)  { ' - ' + page_title}
  end

  def add_tool_tip(message, &block)
    content = capture(&block)
    
    if message.blank?
      concat(content)
      return
    end
    concat("<span title='#{message}'>")
    concat(content)
    concat("</span>")
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



  #################################################################################
  # Selector Helpers
  #################################################################################
  
  def grouped_options_for_select(grouped_options, selected_key = nil, prompt = nil)
    body = ''
    body << content_tag(:option, prompt, :value => "") if prompt
  
    grouped_options = grouped_options.sort if grouped_options.is_a?(Hash)
  
    grouped_options.each do |group|
      body << content_tag(:optgroup, options_for_select(group[1], selected_key), :label => group[0])
    end
  
    body
  end
  
  #Create a standard user select box for selecting a user id for a form.
  #The <pre>parameter_name</pre> argument will be the name of the parameter 
  #when the form is submitted. and the <pre>select_tag_options</pre> hash will be sent
  #directly as options to the <pre>select_tag</pre> helper method called to create the element.
  #The +options+ hash can contain contain either or both of the following:
  #[selector] used for default selection. This can be a User object, a user id (String or Fixnum),
  #           or any model that has a user_id attribute.
  #[users] the array of User objects used to build the select box. Defaults to <pre>current_user.available_users</pre>.
  def user_select(parameter_name = "user_id", options = {}, select_tag_options = {} )
    options  = { :selector => options } unless options.is_a?(Hash)
    selector = options[:selector]
    users    = options[:user] || current_user.available_users
    
    if selector.respond_to?(:user_id)
      sel = selector.user_id.to_s
    elsif selector.is_a?(User)
      sel = selector.id.to_s
    else
      sel = selector.to_s
    end 
    render :partial => 'layouts/user_select', :locals  => { :parameter_name  => parameter_name, :selected  => sel, :users  => users, :select_tag_options => select_tag_options}
  end
  
  #Create a standard groups select box for selecting a group id for a form.
  #The <pre>parameter_name</pre> argument will be the name of the parameter 
  #when the form is submitted. and the <pre>select_tag_options</pre> hash will be sent
  #directly as options to the <pre>select_tag</pre> helper method called to create the element.
  #The +options+ hash can contain contain either or both of the following:
  #[selector] used for default selection. This can be a Group object, a group id (String or Fixnum),
  #           or any model that has a group_id attribute.
  #[groups] the array of Group objects used to build the select box. Defaults to <pre>current_user.available_groups</pre>.
  def group_select(parameter_name = "group_id", options = {}, select_tag_options = {} )
    options  = { :selector => options } unless options.is_a?(Hash)
    selector = options[:selector]
    groups    = options[:groups] || current_user.available_groups
    
    if selector.respond_to?(:group_id)
      sel = selector.group_id.to_s
    elsif selector.is_a?(Group)
      sel = selector.id.to_s
    else
      sel = selector.to_s
    end
    
    render :partial => 'layouts/group_select', :locals  => { :parameter_name  => parameter_name, :selected  => sel, :groups  => groups, :select_tag_options => select_tag_options}
  end
  
  #Create a standard data provider select box for selecting a data provider id for a form.
  #The <pre>parameter_name</pre> argument will be the name of the parameter 
  #when the form is submitted. and the <pre>select_tag_options</pre> hash will be sent
  #directly as options to the <pre>select_tag</pre> helper method called to create the element.
  #The +options+ hash can contain contain either or both of the following:
  #[selector] used for default selection. This can be a DataProvider object, a data provider id (String or Fixnum),
  #           or any model that has a data_provider_id attribute.
  #[data_providers] the array of DataProvider objects used to build the select box. Defaults to all data providers
  #                 accessible by this user.
  def data_provider_select(parameter_name = "data_provider_id", options = {}, select_tag_options = {} )
    options  = { :selector => options } unless options.is_a?(Hash)
    selector = options[:selector]
    if selector.blank? && current_user.user_preference
      selector = current_user.user_preference.data_provider_id
    end
    data_providers = options[:data_providers] || DataProvider.find_all_accessible_by_user(current_user)
    
    if selector.respond_to?(:data_provider_id)
      sel = selector.data_provider_id.to_s
    elsif selector.is_a?(DataProvider)
      sel = selector.id.to_s
    else
      sel = selector.to_s
    end 
    render :partial => 'layouts/data_provider_select', :locals  => { :parameter_name  => parameter_name, :selected  => sel, :data_providers  => data_providers, :select_tag_options => select_tag_options}
  end

  #Create a standard bourreau select box for selecting a bourreau id for a form.
  #The <pre>parameter_name</pre> argument will be the name of the parameter 
  #when the form is submitted. and the <pre>select_tag_options</pre> hash will be sent
  #directly as options to the <pre>select_tag</pre> helper method called to create the element.
  #The +options+ hash can contain contain either or both of the following:
  #[selector] used for default selection. This can be a Bourreau object, a Boureau id (String or Fixnum),
  #           or any model that has a bourreau_id attribute.
  #[bourreaux] the array of Bourreau objects used to build the select box. Defaults to all bourreaux
  #            accessible by this user.
  def bourreau_select(parameter_name = "bourreau_id", options = {}, select_tag_options = {} )
    options  = { :selector => options } unless options.is_a?(Hash)
    selector = options[:selector]
    if selector.blank? && current_user.user_preference
      selector = current_user.user_preference.bourreau_id
    end
    bourreaux = options[:bourreaux] || Bourreau.find_all_accessible_by_user(current_user)
    
    if selector.respond_to?(:bourreau_id)
      sel = selector.bourreau_id.to_s
    elsif selector.is_a?(Bourreau)
      sel = selector.id.to_s
    else
      sel = selector.to_s
    end 
    render :partial => 'layouts/bourreau_select', :locals  => { :parameter_name  => parameter_name, :selected  => sel, :bourreaux  => bourreaux, :select_tag_options => select_tag_options}
  end



  #################################################################################
  # Link Helpers
  #################################################################################
  
  #Creates a link labeled +name+ to the url +path+ *if* *and* *only* *if*
  #the current user has a role of *admin*. Otherwise, +name+ will be 
  #displayed as static text.
  def link_if_admin(name, path)
    if check_role(:admin)
      link_to(name, path)
    else
      name
    end
  end
  
  #Creates a link labeled +name+ to the url +path+ *if* *and* *only* *if*
  #the current user has a role of *admin* or <b>site manager</b>. Otherwise, +name+ will be 
  #displayed as static text.
  def link_if_manager(name, path)
    if check_role(:admin) || check_role(:site_manager)
      link_to(name, path)
    else
      name
    end
  end
  
  #Creates a link labeled +name+ to the url +path+ *if* *and* *only* *if*
  #the current user has access to +resource+. Otherwise, +name+ will be 
  #displayed as static text.
  def link_if_has_access(resource, name, path)
    if resource.can_be_accessed_by?(current_user)
      link_to(name, path)
    else
      name
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
    name = crop_text_to(40, options[:name] || userfile.name)
    path = options[:path] || edit_userfile_path(userfile)
    if userfile.available? && userfile.can_be_accessed_by?(user)
      link_to(name, path)
    else
      name
    end
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
    return if current_order == nil
    
    #order, direction = session_order.sub("type, ", "").split
    
    return unless location == current_order
    
    if location == 'userfiles.lft' || location == 'cbrain_tasks.launch_time DESC, cbrain_tasks.created_at'
      icon = '<font color="Red">&nbsp;&bull;</font>'
    else
      icon = '<font color="Red">&nbsp;&dArr;</font>'
      if current_dir == 'DESC'
        icon = '<font color="Red">&nbsp;&uArr;</font>'
      end
    end
    
    icon
  end
  
  ############################################################
  #                                              
  # This class is used to create a tabs          
  # the TabBar.tab creates individual tabs       
  # You can give TabBar.tab a partial or         
  # simply a block to define the content         
  #                                              
  # To initialize, provide it with a                         
  # reference to ActionView::Helpers::CaputreHelper::capture 
  # and ActionView::TemplateHelperHandler::render                                                         
  #############################################################
  class TabBar
    
    def initialize(capture,render)
      @tab_titles = "<ul>\n"
      @tab_divs = ""
      @capture = capture #HACK ALERT:This is the the capture method given to the object on creation, 
                         #since this class can't access 
                         #Things from the enclosing module
      @render = render   #HACK ALERT: same thing as the capture, it's the render from the surrounding module
                         #horrible code, don't attempt at home
    end

    attr_reader :tab_titles, :tab_divs
    attr_writer :tab_titles #Making this writable because I need to add a </ul> to it. 

    
    #This creates an individual tab, it either takes a block and/or a partial as an option (:partial => "partial")
    def tab(options, &block)
      @tab_titles += "<li "
      if options[:class]
        @titles +="class='##{options[:class]}' "
      end
      @tab_titles +="><a href='##{options[:name].gsub(' ','_')}'>#{options[:name]}</a></li>"
      

      #########################################
      #tab content div.                       #
      #                                       #
      #This can be either a partial or a block#
      #########################################
      @tab_divs += "<div id=#{options[:name].gsub(' ','_')}>\n" 
      if options[:partial]
       @tab_divs += @render.call( :partial => options[:partial])
      end
      if block
        @tab_divs += @capture.call(&block)
      end
      @tab_divs += "</div>\n"      
    end
    
  end



  def tab_bar(&block)

    foo="nothing" #can't have bar without foo (what's the point of comments if there's no jokes ;p)

    #THIS LINE CONTAINS METAPROGRAMMING
    #The TabBar class can't access the capture method and the render method so we are passing them
    #in as a initialization variable
    #This is obviously horrible coding practice 
    bar=TabBar.new(method(:capture),method(:render))
    

    capture(bar,&block)
    bar.tab_titles +="</ul>"
    concat("<div class='tabs'>")
    concat(bar.tab_titles)
    concat(bar.tab_divs)
    concat("</div>")
  end
  
  def inplace_edit_field(options)
    name = options[:name]
    label = options[:label]
    initial = options[:initial_value] || ""
    "<div class=\"inline_edit_field\">"+
      "<span>"+
        "#{label}:  "+
        "<span class=\"current_text\">#{initial}</span>"+
        "<input name=\"#{name}\" />"+
      "</span>" +
      "<a class=\"inplace_edit_field_save\" >save</a>"+
    "</div>" 
    
  end

  #Create an overlay dialog box with a link as the button
  def overlay_dialog_with_button(options,html_opts={},&block)
    partial = options[:partial]
    name = options[:name]
    button_text = options[:button_text]
    width = options[:width] || ""
    if partial
      content = render :partial  => partial
    else
      content = capture(&block)
    end
    
    
    html_opts[:class] ||= ""
    html_opts[:class] +=  " dialog"
    if width
      html_opts["data-width"] = width
    end
    atts = html_opts.inject(""){|result, att| result+="#{att.first}=\"#{att.last}\" "} #Thanks tarek for the trick ;p 
    

    concat("<div class=\"overlay_dialog\">")
    concat("<div id=\"#{name}\" #{atts}>")
    concat(content)
    concat("</div>")
    concat("<a class=\"dialog_button button\">#{button_text}</a>")
    concat("</div>")
  end
  
 
  ###############################################################
  # Creates an html element which will have it's content updated 
  # with a ajax call to the url specified in the options hash
  #
  # example:
  #
  # <% ajax_element( {:url =>"/data_providers", :element => "span"}, {:class => "left right center"})  do %>
  #   loading...
  # <% end %>
  #
  # This will ouput the following html
  # <span href="/data_providers" class="left right center ajax_element" >
  #   loading...
  # </span>
  # 
  # and the body will be replaced with the content of the html at /data_providers
  ###############################################################
  def ajax_element(options,html_opts={},&block) 
    url = options[:url]
    partial = options[:partial]
    element = options[:element] || "div"
    
    html_opts[:class] ||= ""
    html_opts[:class] +=  " ajax_element"
    
    #This builds an html attribute string from the html_opts hash
    atts = html_opts.inject(""){|result, att| result+="#{att.first}=\"#{att.last}\" "} #Thanks tarek for the trick ;p 

    initial_content=capture(&block)+((render partial unless !partial) || "")
    
    concat("<#{element} data-url=\"#{url}\" #{atts}>") 
    concat(initial_content)
    concat("</#{element}>")
  end
 
  ###############################################################
  # Creates an html element which will have it's or another elements 
  # content updated when it is clicked on
  #  with a ajax call to the url specified in the options hash
  #
  # example:
  #
  # <% on_click_ajax_element( {:url =>"/data_providers", :element => "span"}, {:class => "left right center"})  do %>
  #   loading...
  # <% end %>
  #
  # This will ouput the following html
  # <span data-url="/data_providers" class="left right center ajax_onclick_element" >
  #   loading...
  # </span>
  # 
  # and the body will be replaced with the content of the html at /data_providers
  # when you click on the span
  # 
  # replace can be used to specify a selector (jQuery) to find the element(s) 
  # replace
  ###############################################################
  
  def on_click_ajax_replace(options,html_opts={},&block)
    url = options[:url]
    partial = options[:partial]
    element = options[:element] || "div"
    replace = options[:replace] 
    position = options[:position]
    before  = options[:before]
    html_opts[:class] ||= ""
    html_opts[:class] +=  " ajax_onclick_show_element"
    html_opts[:id] ||= "#{Time.now.to_f}"
    if replace
      html_opts["data-replace"] = replace
    end
    if position
      html_opts["data-position"] = position
    end
    if before
      html_opts["data-before"] = before
    end
    #This builds an html attribute string from the html_opts hash
    atts = html_opts.inject(""){|result, att| result+="#{att.first}=\"#{att.last}\" "} #Thanks tarek for the trick ;p 

    
    initial_content=capture(&block)+((render partial unless !partial) || "")
    
    concat("<#{element} data-url=\"#{url}\" #{atts}>") 
    concat(initial_content)
    concat("</#{element}>")
    
  end
  def button_with_dropdown_menu(options={},html_opts={}, &block)
    partial = options[:partial]
    title = options[:title]
    html_opts[:class] ||= ""
    html_opts[:class] +=  " button_menu"
    
    content=""
    if block_given?
      content += capture(&block)
    end
    if partial
      content += render :partial => partial
    end

    atts = html_opts.inject(""){|result, att| result+="#{att.first}=\"#{att.last}\" "} #Thanks tarek for the trick ;p 
    concat("<span class=\"button_with_drop_down\">")
    concat("<a #{atts}>#{title}</a>")
    concat("<div class=\"drop_down_menu\">")
    concat(content)
    concat("</div>")
    concat("</span>")
           
  end
  

  ##################################################################
  # Creates a submit button with the value specified in the helper
  #
  # ex: <%= submit_button({:value => "Move Files"})%>
  #
  #
  # This generates: 
  #
  # <input type="submit" value="Move Files" class="button"/>
  #
  ###################################################################

  def submit_button(value,html_opts={}) 
    html_opts[:class] ||= ""
    html_opts[:class] +=  " button"
    atts = html_opts.inject(""){|result, att| result+="#{att.first}=\"#{att.last}\" "} #Thanks tarek for the trick ;p 
    return "<input type=\"submit\" value=\"#{value}\" #{atts} />"
  end
  
end
