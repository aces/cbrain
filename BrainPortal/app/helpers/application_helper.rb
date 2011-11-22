require 'time'

#Helper methods for all views.
module ApplicationHelper

  Revision_info=CbrainFileRevision[__FILE__]

  #################################################################################
  # Layout Helpers
  #################################################################################
  
  #Sets the text to be displayed in the title bar when a given view is rendered.
  def title(page_title)
    content_for(:title)  { ' - ' + page_title }
  end

  #Will check for associations to display them properly.
  def display_filter(model, key, value, methods = {})
    exceptions = {
      "group" => "project",
      "bourreau"  => "server"
    }
    
    klass = Class.const_get model.to_s.classify
    association = klass.reflect_on_all_associations(:belongs_to).find { |a| a.primary_key_name == key.to_s  }
    if association
      association_key   = association.primary_key_name
      association_name  = association.name.to_s
      association_class = Class.const_get association.class_name
      name_method = methods[association_key.to_sym] || methods[association_name.to_sym] || :name
      object = association_class.find_by_id(value)
      if exceptions[association_name]
        association_name = exceptions[association_name]
      end
      if object
        "#{association_name.humanize}: #{object.send(name_method)}"
      else
        "#{key.to_s.humanize}: #{value}"
      end
    else
      "#{key.to_s.humanize}: #{value}"
    end
  end
  
  #Create a button for displaying an
  #ajax-loaded new panel
  def new_model_button(text, path)
    html =  "<span id=\"new_model\">\n"
    html +=  ajax_link text, path, :class => "button", 
                                   :target => "#new_model",
                                   :id => "new_model_button",
                                   :replace => true, 
                                   :datatype => "html",
                                   :loading_message => "<span class=\"ui-button-text\" style=\"color: red\">Loading...</span>",
                                   :loading_message_target => "#new_model_button"
    
    html +="\n</span>\n"
    
    html.html_safe
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
    return string if string.length <= length
    return string[0,length-3] + "..."
  end

  # Produces a pretty 'delete' symbol (used mostly for removing
  # active filters)
  def delete_icon
    "&nbsp;<span class=\"delete_icon\">&otimes;</span>&nbsp;".html_safe
  end


  
  #################################################################################
  # Used for Access Report
  #################################################################################

  # Produces a pretty red times symbol (used to show unavailable
  # ressources)
  def red_times_icon
    "<span class=\"red_times_icon\">&times;</span>".html_safe
  end

  # Produces a pretty green o (used to show available ressources)
  def green_o_icon
    "<span class=\"green_o_icon\">&#927;</span>".html_safe
  end

  # Produces a legend for acces reports
  def access_legend
    legend  = "<center>\n"
    legend += "#{green_o_icon}: accessible "
    legend += "#{red_times_icon}: not accessible"
    legend += "</center>\n"
    return legend.html_safe
  end

  #################################################################################
  # Used for Disk Usage Report
  #################################################################################
  
  # Returns a RGB color code '#000000' to '#ffffff'
  # for size; the values are all fully saturated
  # and move about the colorwheel from pure blue
  # to pure red along the edge of the wheel. This
  # means no white or black or greys is ever returned
  # by this method. Max indicate to which values
  # and above the pure 'red' results corresponds to.
  # Red axis   = angle   0 degrees
  # Green axis = angle 120 degrees
  # Blue axis  = angle 240 degrees
  # The values are spread from angle 240 down towards angle 0
  def size_to_color(size,max=nil,unit=1)
    max      = 500_000_000_000 if max.nil?
    size     = max if size > max
    percent  = Math.log(1+(size.to_f) / (unit.to_f)) / Math.log((max.to_f) / (unit.to_f))
    angle    = 240-240*percent # degrees

    r_adist = (angle -   0.0).abs ; r_adist = 360.0 - r_adist if r_adist > 180.0
    g_adist = (angle - 120.0).abs ; g_adist = 360.0 - g_adist if g_adist > 180.0
    b_adist = (angle - 240.0).abs ; b_adist = 360.0 - b_adist if b_adist > 180.0

    r_pdist = r_adist < 60.0 ? 1.0 : r_adist > 120.0 ? 0.0 : 1.0 - (r_adist - 60.0) / 60.0
    g_pdist = g_adist < 60.0 ? 1.0 : g_adist > 120.0 ? 0.0 : 1.0 - (g_adist - 60.0) / 60.0
    b_pdist = b_adist < 60.0 ? 1.0 : b_adist > 120.0 ? 0.0 : 1.0 - (b_adist - 60.0) / 60.0

    red   = r_pdist * 255
    green = g_pdist * 255
    blue  = b_pdist * 255

    sprintf "#%2.2x%2.2x%2.2x",red,green,blue
  end

  
  # Produces a colored square (used to show )
  def colored_square(color)
    span  = "<span class=\"display_cell dp_disk_usage_color_span\">"
    span += "  <div class=\"dp_disk_usage_color_block\" style=\"background: #{color}\"></div>"
    span += "</span>"
    span.html_safe
  end

  # Produces cell contain in order to display colored_square 
  # and text side by side
  def disk_space_info_display(size, max_size, unit, &block)
    text = capture(&block)

    cellcolor = size_to_color(size || 0, max_size, unit)
    contain   = "<span class=\"display_cell dp_disk_usage_color_span\">"
    contain  += "<div class=\"dp_disk_usage_color_block\" style=\"background: #{cellcolor}\"></div>"
    contain  += "</span>"
    contain  += "<span class=\"display_cell\">"
    contain  += "#{text}"
    contain  += "</span>"

    return contain.html_safe
  end
  
  # Produces a legend for disk usage reports
  def disk_usage_legend
    legend  = "<center>"
    low_cell_color  = size_to_color(0)
    high_cell_color = size_to_color(100,100)
    
    legend += "<span class=\"display_cell\">"
    legend += "#{colored_square(size_to_color(0))}"
    legend += "<strong class=\"display_cell\">	&#8594; </strong>" 
    legend += "#{colored_square(size_to_color(100,100))}"
    legend += "</span>"
    legend += "<br/>"
    legend += "Low to High disk usage"
    legend += "</center>"
    return legend.html_safe
  end



  # Splits a description into a header and a body; both are returned as strings
  # in a two-element array.
  def split_description(description="")
    return [ "", "" ] if description.blank?
    raise "Internal error: can't parse description!?!" unless description =~ /^(.*\n?)/ # the . doesn't match \n , which is OK!
    header = Regexp.last_match[1].strip
    body   = (description[header.size,999] || "").strip
    return [ header, body ]
  end

  # Takes a +description+ (a string with possibly multiple lines) and shows
  # the first line only; other lines if present will be made accessible
  # through a link called '(more)' which launches an overlay.
  def overlay_description(description=nil, options={})
    header,body    = split_description(description)
    cropped_header = crop_text_to(options[:header_width] || 50,header)
    return h(cropped_header) if body.blank? && cropped_header !~ /\.\.\.$/

    link = h(cropped_header) + " " + 
      overlay_content_link("(more)", :enclosing_element => 'span' ) do
        ("<h2>#{h(header)}</h2>\n<pre>" + h(body) + "</pre>").html_safe
      end
    link.html_safe
  end

  # Creates a link called "(info)" that presents as an overlay
  # the set of descriptions for the data providers given in argument.
  def overlay_data_providers_descriptions(data_providers = nil)
    data_providers ||= DataProvider.find_all_accessible_by_user(current_user)
    paragraphs = data_providers.collect do |dp|
      one_description = <<-"HTML"
        <h3>#{h(dp.name)}</h3>
        <pre>#{dp.description.blank? ? "(No description)" : h(dp.description.strip)}</pre>
      HTML
    end
    all_descriptions = <<-"HTML"
      <h2>Data Providers Descriptions</h2>
      <div class="generalbox">#{paragraphs.join("")}</div>
    HTML
    link =
       overlay_content_link("(info)", :enclosing_element => 'span') do
         all_descriptions.html_safe
       end
    link.html_safe
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
      sort_order.to_s.upcase == 'DESC' ? '' : 'DESC'
    end
  end
  
  #Set arrow icon for ordering of userfiles. I.e. display a red arrow
  #next to the header of a given column in the Userfile index table *if*
  #that column is the one currently determining the order of the file.
  #
  #Toggles the direction of the arrow depending on whether the order is 
  #ascending or descending.
  def set_order_icon(loc, current_order, current_dir = nil)
    return "" if current_order == nil    
    
    table_name, table_col = loc.strip.split(".")
    table_name = table_name.tableize
    location = table_name + "." + table_col
    
    return "" unless location == current_order
    
    if location == 'userfiles.tree_sort' || location == 'cbrain_tasks.batch'
      icon = '&bull;'
    else
      icon = (current_dir == 'DESC') ? '&uarr;' : '&darr;'
    end
    
    "<span class=\"order_icon\">#{icon}</span>".html_safe
  end

  def index_count_filter(count, controller, filters, options={})
     count = count.to_i
     return ""  if count == 0 && ! ( options[:show_zeros] || options[:link_zeros] )
     return "0" if count == 0 && ! options[:link_zeros]
     filter_reset_link count,
                       :controller   => controller,
                       :filters      => filters,
                       :ajax         => false,
                       :clear_params => options[:clear_params]
  end


  #################################################################################
  # Javascript helpers
  #################################################################################
  
  ##################################################################
  # MAKE SURE THIS HASH MATCHES THE REGEX BELOW IN html_for_js() !!!
  ##################################################################
  
  HTML_FOR_JS_ESCAPE_MAP = {
  #  '"'     => '\\"',    # wrong, we leave it as is
  #  '</'    => '<\/',    # wrong too
    '\\'    => '\\\\',
    "\r\n"  => '\n',
    "\n"    => '\n',
    "\r"    => '\n',
    "'"     => "\\'"
  }

  # Escape a string containing HTML code so that it is a valid
  # javascript constant string; the string will be quoted
  # with single quotes (') on each end.
  # There exists a helper in module ActionView::Helpers::JavaScriptHelper
  # called escape_javascript(), but it also escapes some character sequences
  # that create problems within Javascript code intended to substitute
  # HTML in a document.
  def html_for_js(string)
    # "'" + string.gsub("'","\\\\'").gsub(/\r?\n/,'\n') + "'"
    return "''".html_safe if string.nil? || string == ""
    with_substititions = string.gsub(/(\\|\r?\n|[\n\r'])/) { HTML_FOR_JS_ESCAPE_MAP[$1] } # MAKE SURE THIS REGEX MATCHES THE HASH ABOVE!
    with_quotes = "'#{with_substititions}'"
    with_quotes.html_safe
  end

end
