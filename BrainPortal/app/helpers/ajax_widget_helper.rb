module AjaxWidgetHelper
  
  Revision_info=CbrainFileRevision[__FILE__]
  
  include JavascriptOptionSetup
  
  #Create a button for displaying an
  #ajax-loaded new panel
  def new_model_button(text, path)
    html =  "<span id=\"new_model\">\n"
    html +=  ajax_link text, path, :class => "button menu_button", 
                                   :target => "#new_model",
                                   :id => "new_model_button",
                                   :replace => true, 
                                   :datatype => "html",
                                   :loading_message => "<span class=\"ui-button-text\" style=\"color: red\">Loading...</span>",
                                   :loading_message_target => "#new_model_button"
    
    html +="\n</span>\n"
    
    html.html_safe
  end
  
  #Create an inline edit field.
  def inline_text_field(p_name, url, options = {}, &block)
    name = p_name
    initial_text = capture(&block)
    initial_value = options.delete(:initial_value) || initial_text
    field_label = options.delete(:label)
    field_label += ":  " unless field_label.blank?
    method = options.delete(:method) || "post"
    method = method.to_s.downcase
    
    options_setup("inline_text_field", options)
    options["data-trigger"] = options.delete(:trigger) || ".current_text"
    
    atts = options.inject(""){|result, att| result+="#{att.first}=\"#{att.last}\" "} #Thanks tarek for the trick ;p  You're welcome!
    
    safe_concat("<div #{atts}>")
    safe_concat("<span class=\"current_text\">#{initial_text}</span>")
    safe_concat(form_tag_html(:action  => url_for(url), :class  => "inline_text_form", :method => method)) 
    safe_concat("#{field_label}")
    safe_concat(text_field_tag(name, initial_value, :class => "inline_text_input")) 
    safe_concat("</form>")
    safe_concat("</div>") 
    ""
  end
  
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
    element = options.delete(:element) || "div"
    
    data = options.delete(:data)
    if data
      options["data-data"] = h data.to_json
    end
    
    options_setup("ajax_element", options)
    
    options["data-url"] = url
    
    #This builds an html attribute string from the html_opts hash
    atts = options.inject(""){|result, att| result+="#{att.first}=\"#{att.last}\" "} #Thanks tarek for the trick ;p  You're welcome!
    
    initial_content = capture(&block) if block_given?
    initial_content ||= html_colorize("Loading...")
    
    html = "<#{element} #{atts}>"
    html += h(initial_content)
    html += "</#{element}>"
    
    html.html_safe
  end
  
  #Request some js through ajax to be run on the current page.
  def script_loader(url, options = {})
    options["data-url"] = url
         
    options[:class] ||= ""
    options[:class] +=  " script_loader"
    
    #This builds an html attribute string from the html_opts hash
    atts = options.inject(""){|result, att| result+="#{att.first}=\"#{att.last}\" "} #Thanks tarek for the trick ;p  You're welcome!
    
    "<div #{atts}></div>".html_safe
  end
  
  #Staggered load elements request their content one at a time.
  #
  #Options:
  #[:error_message] HTML to display if the request fails.
  #[:replace] whether the entire element should be replaced (as
  #           opposed to just the content).
  def staggered_loading(element, url, options={}, &block) 
    options_setup("staggered_loader", options)
    options["data-url"] = url
     
    atts = options.inject(""){|result, att| result+="#{att.first}=\"#{att.last}\" "}
    if block_given?
      initial_content=capture(&block)
    else
      initial_content = ""
    end
    
    html = "<#{element} #{atts}>"
    html += h(initial_content)
    html += "</#{element}>"
    
    html.html_safe
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
    html_opts[:onclick] ||= '""'  # for iOS devices like iPads...
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
    
    safe_concat("<#{element} data-url=\"#{url}\" #{atts}>") 
    safe_concat(initial_content)
    safe_concat("</#{element}>")
    ""
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
    options_setup("search_box", options)
    
    options["data-url"] = url  
    default_value = options.delete(:default)
    
    text_field_tag(name, default_value, options)
  end
  
  #Create an overlay dialog box with a link as the button.
  #Content is provided through an ajax request.
  #+options+ same as for link_to
  #
  def overlay_ajax_link(name, url, options = {})
    options[:datatype] ||= "html"
    options[:overlay] = true
    
    ajax_link h(name.to_s), url, options
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
    options_setup("ajax_link", options)
    options[:remote] = true
    
    link_to h(name.to_s), url, options 
  end
  
  #Create a link that will submit an ajax request. The 
  #difference between this and ajax_link is that it is assumed
  #this link will be removing/updating something in the page, and
  #thus has some options for manipulating the page prior to sending
  #the request.
  #
  #Aside from the options for ajax_link there are:
  #[:loading_message] text with which to update the target elements
  #               prior to sending the request.
  #[:confirm] Confirm message to display before sending the request.
  def delete_button(name, url, options = {})
    options[:method] ||= 'DELETE'
    options[:datatype] ||= 'script'
    
    ajax_link h(name.to_s), url, options
  end
  
  #A select box that will update the page onChange.
  #
  #Options:
  #[:datatype] the datatype expected from the request (HTML, XML, script...).
  #[:method] HTTP method to use for the request.
  #[:target] selector for elements to update prior to or after the
  #         the request is sent.
  #[:loading_message] text with which to update the target elements
  #               prior to sending the request.
  #All other options treated as HTML attributes.
  def ajax_onchange_select(name, url, option_tags, options = {})
    options_setup("request_on_change", options)
    
    options["data-url"] = url
    
    select_tag(name, option_tags, options)
  end
  
end