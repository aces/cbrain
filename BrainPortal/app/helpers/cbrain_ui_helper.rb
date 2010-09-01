#UI helpers
module CbrainUiHelper

  Revision_info="$Id$"
  
  #Create tab bars in the interface.
  #Content is provided with a block.
  #[options] A hash of html options for the tab bar structure.
  #Usage:
  # <% build_tabs do |tb| %>
  #   <% tb.tab "First Tab" do %>
  #      <h1>First tab contents</h1>
  #      More contents.
  #   <% end %>
  #   <% tb.tab "Second Tab" do %>
  #      Wow! Even more contents!
  #   <% end %>
  # <% end %>
  #
  #
  def build_tabs(options = {}, &block)
     bar = TabBuilder.new

     options[:class] ||= ""
     options[:class] +=  " tabs"

     atts = options.inject(""){|result, att| result+="#{att.first}=\"#{att.last}\" "}

     capture(bar,&block)  #Load content into bar object

     concat("<div #{atts}>")
     concat(bar.tab_titles)
     concat(bar.tab_divs)
     concat("</div>")
   end
  
  ############################################################
  #                                              
  # Utility class for the build_tabs method (see above).      
  #                                                                          
  #############################################################
  class TabBuilder
    
    def initialize
      @tab_titles = ""
      @tab_divs   = ""
    end
    
    def tab_titles
      "<ul>\n" + @tab_titles + "\n</ul>\n"
    end
    
 

    attr_reader :tab_divs
    
    #This creates an individual tab, it either takes a block and/or a partial as an option (:partial => "partial")
    def tab(name, &block)
      capture = eval("method(:capture)", block.binding)
      @tab_titles += "<li><a href='##{name.gsub(/\s+/,'_')}'>#{name}</a></li>"
      

      #########################################
      #tab content div.                       #
      #                                       #
      #This can be either a partial or a block#
      #########################################
      @tab_divs += "<div id=#{name.gsub(/\s+/,'_')}>\n" 
      @tab_divs += capture.call(&block)
      @tab_divs += "</div>\n"      
    end
  end
  
  
  #Create accordion menus in the interface.
  #Content is provided with a block.
  #[options] A hash of html options for the accordion structure.
  #Usage:
  # <% build_accordion do |acc| %>
  #   <% acc.section "Section Header" do %>
  #      <h1>First section contents</h1>
  #      More contents.
  #   <% end %>
  #   <% acc.section "Section Two" do %>
  #      Wow! Even more contents!
  #   <% end %>
  # <% end %>
  #
  #
  def build_accordion(options = {}, &block)
    options[:class] ||= ""
    options[:class] +=  " accordion"
    
    atts = options.inject(""){|result, att| result+="#{att.first}=\"#{att.last}\" "}
    
    content = capture(AccordionBuilder.new, &block)
    
    concat("<div #{atts}>")
    concat(content)
    concat("</div>")
  end
  
  ############################################################
  #                                              
  # Utility class for the build_accordion method (see above).      
  #                                                                          
  #############################################################
  class AccordionBuilder
    def section(header, &block)
      capture = eval("method(:capture)", block.binding)
      concat = eval("method(:concat)", block.binding)
      head = "<h3><a href=\"#\">#{header}</a></h3>"
      body = "<div>#{capture.call(&block)}</div>"
      concat.call(head)
      concat.call(body)
    end
  end
  
  #Create an inline edit field.
  #
  #INCOMPLETE: the ability to submit an update on save should be added.
  #current needs to be part of a form.
  def inline_edit_field(options = {})
    name = options[:name]
    field_label = options[:label]
    initial = options[:initial_value] || ""
    "<div class=\"inline_edit_field\">"+
      "<span>"+
        "#{field_label}:  "+
        "<span class=\"current_text\">#{initial}</span>"+
        "<input name=\"#{name}\" />"+
      "</span>" +
      "<a class=\"inplace_edit_field_save\">Save</a>"+
    "</div>" 
  end

  #Create an overlay dialog box with a link as the button.
  #Content is provided through a block.
  #Options: 
  # [width] width in pixels of the overlay.
  #
  #All other options will be treated at HTML attributes.
  #
  #Usage:
  # <% overlay_content "Click me" do %>
  #   This content will be in the overlay
  # <% end %>
  #
  def overlay_content_link(name, options = {}, &block)
    options[:class] ||= ""
    options[:class] +=  " overlay_content_link"
    
    options[:href] ||= "#"
    
    width = options.delete :width
    if width
      options["data-width"] = width
    end
    
    element = options.delete(:enclosing_element) || "div"
    
    atts = options.inject(""){|result, att| result+="#{att.first}=\"#{att.last}\" "} #Thanks tarek for the trick ;p  You're welcome!
    
    content = capture(&block)

    concat("<#{element} class=\"overlay_dialog\">")
    concat("<a #{atts}>#{name}</a>")
    concat("<div class=\"overlay_content\">")
    concat(content)
    concat("</div>")
    concat("</#{element}>")
  end
  
  #Create a button with a drop down menu
  #
  #Options:
  #[:partial] a partial to render as the content of the menu.
  #[:content_id] id of the menu section of the structure.
  #[:button_id] id of the button itself.
  #All other options are treated as HTML attributes on the
  #enclosing span.
  def button_with_dropdown_menu(title, options={}, &block)
    partial    = options.delete :partial
    content_id = options.delete :content_id
    content_id = "id=\"#{content_id}\"" if content_id
    button_id = options.delete :button_id
    button_id = "id=\"#{button_id}\"" if button_id
    options[:class] ||= ""
    options[:class] +=  " button_with_drop_down"
    
    content=""
    if block_given?
      content += capture(&block)
    end
    if partial
      content += render :partial => partial
    end

    atts = options.inject(""){|result, att| result+="#{att.first}=\"#{att.last}\" "} #Thanks tarek for the trick ;p  You're welcome!
    concat("<span #{atts}>")
    concat("<a #{button_id} class=\"button_menu\">#{title}</a>")
    concat("<div #{content_id} class=\"drop_down_menu\">")
    concat(content)
    concat("</div>")
    concat("</span>")
           
  end
  

  ##################################################################
  # Creates a submit button with the value specified in the helper
  #
  # ex: <%= submit_button("Move Files")%>
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
    atts = html_opts.inject(""){|result, att| result+="#{att.first}=\"#{att.last}\" "} #Thanks tarek for the trick ;p  You're welcome!
    return "<input type=\"submit\" value=\"#{value}\" #{atts} />"
  end
  
  #Create an element that will toggle between hiding and showing another element.
  #The appearance/disappearance can also be animated.
  def show_hide_toggle(text, target, options = {})
    element_type = options.delete(:element_type) || "a"
    if element_type.downcase == "a"
      options["href"] ||= "#"
    end
    options["data-target"] = target
    alternate_text = options.delete(:alternate_text)
    if alternate_text
      options["data-alternate-text"] = alternate_text
    end
    slide_effect = options.delete(:slide_effect)
    if slide_effect
      options["data-slide-effect"] = true
    end
    slide_duration = options.delete(:slide_duration)
    if slide_duration
      options["data-slide-duration"] = slide_duration
    end
    
    options[:class] ||= ""
    options[:class] +=  " show_toggle"
    
    atts = options.inject(""){|result, att| result+="#{att.first}=\"#{att.last}\" "}
    return" <#{element_type} #{atts}>#{text}</#{element_type}>"
  end
  
  #Create a checkbox that will select or deselect all checkboxes on the page 
  #of class +checkbox_class+.
  #+options+ are just treated as HTML attributes.
  def select_all_checkbox(checkbox_class, options = {})
    options[:class] ||= ""
    options[:class] +=  " select_all"
    
    options["data-checkbox-class"] = checkbox_class
    atts = options.inject(""){|result, att| result+="#{att.first}=\"#{att.last}\" "} 
    
    "<input type='checkbox' #{atts}/>"
  end
  
  #Create a select box with options +select_options+ that will manipulate
  #all select boxes on the page of class +select_class+ to switch to 
  #share its current selection (if it is one of their options).
  #+options+ are treated as HTML attributes.
  def master_select(select_class, select_options, options = {})
    options[:class] ||= ""
    options[:class] +=  " select_master"
    
    options["data-select-class"] = select_class
    atts = options.inject(""){|result, att| result+="#{att.first}=\"#{att.last}\" "} 
    
    result =  "<select #{atts}>\n"
    result += select_options.map{|text| "<option>#{text}</option>"}.join("\n")
    result += "</select>"
  end
  
  ###########################################
  #
  # Delayed content loading helpers
  #
  ###########################################
  
  ###############################################################
  # Creates an html element which will have it's content updated 
  # with a ajax call to the url specified in the options hash
  #
  # Options:
  # [:element] the type of element to generate. Defaults to "div".
  # All other options will be treated as HTML attributes.
  #
  # Example:
  #
  # <% ajax_element( "/data_providers", :element => "span", :class => "left right center")  do %>
  #   loading...
  # <% end %>
  #
  # This will ouput the following html
  # <span data-url="/data_providers" class="left right center ajax_element" >
  #   loading...
  # </span>
  # 
  # and the body will be replaced with the content of the html at /data_providers
  ###############################################################
  def ajax_element(url, options ={}, &block) 
    options["data-url"] = url
    element = options.delete(:element) || "div"
    
    options[:class] ||= ""
    options[:class] +=  " ajax_element"
    
    #This builds an html attribute string from the html_opts hash
    atts = options.inject(""){|result, att| result+="#{att.first}=\"#{att.last}\" "} #Thanks tarek for the trick ;p  You're welcome!
    
    initial_content = capture(&block)
    
    concat("<#{element} #{atts}>") 
    concat(initial_content)
    concat("</#{element}>")
  end
  
  #Request some js through ajax to be run on the current page.
  def script_loader(url, options = {})
    options["data-url"] = url
         
    options[:class] ||= ""
    options[:class] +=  " script_loader"
    
    #This builds an html attribute string from the html_opts hash
    atts = options.inject(""){|result, att| result+="#{att.first}=\"#{att.last}\" "} #Thanks tarek for the trick ;p  You're welcome!
    
    "<div #{atts}></div>" 
  end
  
  #Staggered load elements request their content one at a time.
  #
  #Options:
  #[:error_message] HTML to display if the request fails.
  #[:replace] whether the entire element should be replaced (as
  #           opposed to just the content).
  def staggered_loading(element, url, options={}, &block) 
    options[:class] ||= ""
    options[:class] +=  " staggered_loader"
    
    options["data-url"] = url
    
    error_message = options.delete(:error_message)
    if error_message
      options["data-error"] = h(error_message)
    end
    
    replace = options.delete(:replace)
    if replace
      options["data-replace"] = replace
    end
     
    atts = options.inject(""){|result, att| result+="#{att.first}=\"#{att.last}\" "}
    if block_given?
      initial_content=capture(&block)
    else
      initial_content = ""
    end
    
    concat("<#{element} #{atts}>") 
    concat(initial_content)
    concat("</#{element}>")
  end
  
  
  ###########################################
  #
  # Ajax widgets
  #
  ###########################################
  
  ###############################################################
  # Creates an html element which will have its or another element's 
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
    atts = html_opts.inject(""){|result, att| result+="#{att.first}=\"#{att.last}\" "} #Thanks tarek for the trick ;p  You're welcome!

    
    initial_content=capture(&block)+((render partial unless !partial) || "")
    
    concat("<#{element} data-url=\"#{url}\" #{atts}>") 
    concat(initial_content)
    concat("</#{element}>")
    
  end
  
  #Creates a text field that will sends an ajax
  #request to +url+ when the enter key is hit. The current
  #text is sent as parameter +name+.
  #
  #Options:
  #[:default] initial text in the field.
  #[:datatype] the datatype expected from the request (HTML, XML, script...).
  #[:method] HTTP method to use for the request.
  #[:target] selector indicating where the response data should be place in the 
  #          page.
  #All other options treated as HTML attributes.
  def ajax_search_box(name, url, options = {})
    options[:class] ||= ""
    options[:class] +=  " search_box"
    
    options["data-url"] = url
    
    default_value = options.delete(:default)
    
    data_type = options.delete(:datatype)
    if data_type
      options["data-datatype"] = data_type.to_s.downcase
    end
    
    method = options.delete(:method)
    if method
      options["data-method"] = method.to_s.upcase
    end
    
    target = options.delete(:target)
    if target
      options["data-target"] = target
    end
    
    text_field_tag(name, default_value, options)
  end
  
  #Create an overlay dialog box with a link as the button.
  #Content is provided through an ajax request.
  #+options+ same as for link_to
  #
  def overlay_ajax_link(name, url, options = {})
    options[:class] ||= ""
    options[:class] +=  " overlay_ajax_link"
        
    link_to name, url, options
  end
  
  #Create a link that will submin an ajax_request to +url+
  #
  #Creates a text field that will sends an ajax
   #request to +url+ when the enter key is hit. The current
   #text is sent as parameter +name+.
   #
   #Options:
   #[:datatype] the datatype expected from the request (HTML, XML, script...).
   #[:method] HTTP method to use for the request.
   #[:target] selector indicating where the response data should be place in the 
   #          page.
   #All other options treated as HTML attributes.
  def ajax_link(name, url, options = {})
    options[:class] ||= ""
    options[:class] +=  " ajax_link"
    
    data_type = options.delete(:datatype)
    if data_type
      options["data-datatype"] = data_type.to_s.downcase
    end
    
    method = options.delete(:method)
    if method
      options["data-method"] = method.to_s.upcase
    end
    
    target = options.delete(:target)
    if target
      options["data-target"] = target
    end
    
    link_to name, url, options 
  end
  
  #Create a link that will submit an ajax request. The 
  #difference between this and ajax_link is that it is assumed
  #this link will be removing/updating something in the page, and
  #thus has some options for manipulating the page prior to sending
  #the request.
  #
  #Aside from the options for ajax_link there are:
  #[:target_text] text with which to update the target elements
  #               prior to sending the request.
  #[:confirm] Confirm message to display before sending the request.
  def delete_button(name, url, options = {})
    options[:class] ||= ""
    options[:class] +=  " delete_button"
    
    data_type = options.delete(:datatype)
    if data_type
      options["data-datatype"] = data_type.to_s.downcase
    end
    
    method = options.delete(:method)
    if method
      options["data-method"] = method.to_s.upcase
    end
    
    target = options.delete(:target)
    if target
      options["data-target"] = target
    end
    
    target_text = options.delete(:target_text)
    if target_text
      options["data-target-text"] = target_text
    end
    
    confirm = options.delete(:confirm)
    if confirm
      options["data-confirm"] = confirm
    end
    
    link_to name, url, options
  end
  
  #A select box that will update the page onChange.
  #
  #Options:
  #[:datatype] the datatype expected from the request (HTML, XML, script...).
  #[:method] HTTP method to use for the request.
  #[:target] selector for elements to update prior to or after the
  #         the request is sent.
  #[:target_text] text with which to update the target elements
  #               prior to sending the request.
  #All other options treated as HTML attributes.
  def ajax_onchange_select(name, url, option_tags, options = {})
    options[:class] ||= ""
    options[:class] +=  " request_on_change"
    
    options["data-url"] = url
    
    data_type = options.delete(:datatype)
    if data_type
      options["data-datatype"] = data_type.to_s.downcase
    end
    
    method = options.delete(:method)
    if method
      options["data-method"] = method.to_s.upcase
    end
    
    target = options.delete(:target)
    if target
      options["data-target"] = target
    end
    
    update_text = options.delete(:target_text)
    if update_text
      options["data-target-text"] = update_text
    end
    
    select_tag(name, option_tags, options)
  end
  
  #Sort links meant specifically for sorting tables.
  #Controller and action for the request can be defined in the options hash, or
  #they default to the current page.
  def ajax_sort_link(name, sort_column, options = {})
    controller = options.delete(:controller) || params[:controller]
    action = options.delete(:action) || params[:actions]
    url = { :controller  => controller, :action  => action, controller  => {:sort  => {:order  => sort_column, :dir  => set_dir(sort_column, @filter_params["sort"])}} }
    link_options = options.reverse_merge(:datatype  => 'script')
    ajax_link(name, url, link_options) + "\n" + set_order_icon(sort_column, @filter_params["sort"]["order"], @filter_params["sort"]["dir"])
  end
  
  ###########################################
  #
  # Ajax form helpers
  #
  ###########################################
  
  #Ajax version of form_tag. Takes the exact same options, except for:
  #[:datatype] the datatype expected from the request (HTML, XML, script...).
  #[:method] HTTP method to use for the request.
  #[:target] selector for elements to update prior to or after the
  #         the request is sent.
  def ajax_form_tag(url_for_options = {}, options = {}, *parameters_for_url, &block)
    options[:class] ||= ""
    options[:class] +=  " ajax_form"
    
    data_type = options.delete(:datatype)
    if data_type
      options["data-datatype"] = data_type.to_s.downcase
    end
    
    method = options[:method] #NOTE: not deleted, so it can still be used by rails
    if method
      options["data-method"] = method.to_s.upcase
    end
    
    target = options.delete(:target)
    if target
      options["data-target"] = target
    end
    
    form_tag(url_for_options, options, *parameters_for_url, &block)
  end
  
  #Ajax version of form_for. Takes the exact same options, except for:
  #[:datatype] the datatype expected from the request (HTML, XML, script...).
  #[:method] HTTP method to use for the request.
  #[:target] selector for elements to update prior to or after the
  #         the request is sent.
  def ajax_form_for(record_or_name_or_array, *args, &proc)
    options = args.extract_options!
    
    options[:html] ||= {}
    
    options[:html][:class] ||= ""
    options[:html][:class] +=  " ajax_form"
    
    data_type = options.delete(:datatype)
    if data_type
      options[:html]["data-datatype"] = data_type.to_s.downcase
    end
    
    method = options.delete(:method)  #NOTE: not deleted, so it can still be used by rails
    if method
      options[:html]["data-method"] = method.to_s.upcase
    end
    
    target = options.delete(:target)
    if target
      options[:html]["data-target"] = target
    end
    
    args << options
    
    form_for(record_or_name_or_array, *args, &proc)
  end
  
  #A submit button that hijack the submission of the form in which it appears
  #by for example, sending to a different url, requesting a 
  #different data type, changing the http method, etc.
  #
  #
  #Options:
  #[:datatype] the datatype expected from the request (HTML, XML, script...).
  #[:method] HTTP method to use for the request.
  #[:target] selector for elements to update prior to or after the
  #         the request is sent.
  #[:confirm] Confirm message to display before sending the request.
  def hijacker_submit_button(name, options = {})
    options[:class] ||= ""
    options[:class] +=  " ajax_submit_button"
    
    url = options.delete(:url)
    if url
      options["data-url"] = url
    end
    
    data_type = options.delete(:datatype)
    if data_type
      options["data-datatype"] = data_type.to_s.downcase
    end
    
    method = options.delete(:method)
    if method
      options["data-method"] = method.to_s.upcase
    end
    
    target = options.delete(:target)
    if target
      options["data-target"] = target
    end
    
    confirm = options.delete(:confirm)
    if confirm
      options["data-confirm"] = confirm
    end
    
    submit_tag(name, options)
  end
  
  #A submit button that can be outside the form it submits,
  #which is defined by +form_id+.
  #
  #Options:
  #[:confirm] Confirm message to display before sending the request.
  def external_submit_button(name, form_id, options = {})
    options[:class] ||= ""
    options[:class] +=  " external_submit_button"
    
    options["data-associated-form"] = form_id
    
    confirm = options.delete(:confirm)
    if confirm
      options["data-confirm"] = confirm
    end
    
    submit_tag(name, options)
  end
  
end
