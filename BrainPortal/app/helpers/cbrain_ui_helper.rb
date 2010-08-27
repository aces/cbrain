#UI helpers
module CbrainUiHelper

  Revision_info="$Id$"
  
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
      "<a class=\"inplace_edit_field_save\">Save</a>"+
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
    atts = html_opts.inject(""){|result, att| result+="#{att.first}=\"#{att.last}\" "} #Thanks tarek for the trick ;p  You're welcome!
    

    concat("<div class=\"overlay_dialog\">")
    concat("<div id=\"#{name}\" #{atts}>")
    concat(content)
    concat("</div>")
    concat("<a class=\"dialog_button button\">#{button_text}</a>")
    concat("</div>")
  end
  
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
    atts = html_opts.inject(""){|result, att| result+="#{att.first}=\"#{att.last}\" "} #Thanks tarek for the trick ;p  You're welcome!
    
    if block_given?
      initial_content=capture(&block)+((render partial unless !partial) || "")
    else
      initial_content = ""
    end
    
    concat("<#{element} data-url=\"#{url}\" #{atts}>") 
    concat(initial_content)
    concat("</#{element}>")
  end
  
  #Request some js through ajax to be run on the current page.
  def script_loader(options) 
    url = options.delete(:url)
    
    options[:class] ||= ""
    options[:class] +=  " script_loader"
    
    #This builds an html attribute string from the html_opts hash
    atts = options.inject(""){|result, att| result+="#{att.first}=\"#{att.last}\" "} #Thanks tarek for the trick ;p  You're welcome!
    
    "<div data-url=\"#{url}\" #{atts}></div>" 
  end
  
  #Staggered load elements request their content one at a time.
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

  def button_with_dropdown_menu(options={},html_opts={}, &block)
    partial    = options[:partial]
    title      = options[:title]
    content_id = "id=\"#{options[:content_id]}\"" if options[:content_id]
    html_opts[:class] ||= ""
    html_opts[:class] +=  " button_menu"
    
    content=""
    if block_given?
      content += capture(&block)
    end
    if partial
      content += render :partial => partial
    end

    atts = html_opts.inject(""){|result, att| result+="#{att.first}=\"#{att.last}\" "} #Thanks tarek for the trick ;p  You're welcome!
    concat("<span class=\"button_with_drop_down\">")
    concat("<a #{atts}>#{title}</a>")
    concat("<div #{content_id} class=\"drop_down_menu\">")
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

  def build_accordion(&block)
    content = capture(AccordionBuilder.new, &block)
    
    concat('<div class="accordion">')
    concat(content)
    concat('</div>')
  end
  
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
  
  def select_all_checkbox(checkbox_class, options = {})
    options[:class] ||= ""
    options[:class] +=  " select_all"
    
    options["data-checkbox-class"] = checkbox_class
    atts = options.inject(""){|result, att| result+="#{att.first}=\"#{att.last}\" "} 
    
    "<input type='checkbox' #{atts}/>"
  end
  
  def master_select(select_class, select_options, options = {})
    options[:class] ||= ""
    options[:class] +=  " select_master"
    
    options["data-select-class"] = select_class
    atts = options.inject(""){|result, att| result+="#{att.first}=\"#{att.last}\" "} 
    
    result =  "<select #{atts}>\n"
    result += select_options.map{|text| "<option>#{text}</option>"}.join("\n")
    result += "</select>"
  end
  
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
    
    update_text = options.delete(:update_text)
    if update_text
      options["data-update-text"] = update_text
    end
    
    select_tag(name, option_tags, options)
  end
  
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
  
end
