
#
# CBRAIN Project
#
# Copyright (C) 2008-2012
# The Royal Institution for the Advancement of Learning
# McGill University
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# Helper for dynamic, non-ajax interface elements.
module RichUiHelper

  Revision_info=CbrainFileRevision[__FILE__]

  include JavascriptOptionSetup

  # Takes a +description+ (a string with possibly multiple lines) and shows
  # the first line only; other lines if present will be made accessible
  # through a link called '(more)' which launches an overlay.
  def overlay_description(description="", options={})
    return "" if description.blank?
    header = description.lines.first.strip
    body   = (description[header.size,999] || "").strip
    cropped_header = crop_text_to(options[:header_width] || 50,header)
    return h(cropped_header) if body.blank? && cropped_header !~ /\.\.\.\z/
    return h(cropped_header) if cropped_header.present? && body.present? && (cropped_header == body)

    link = h(cropped_header) + " " +
      html_tool_tip(link_to("(more)", "#"), :offset_x => 0, :offset_y => 20) do
        pre_body = body.blank? ? "" : "\n<pre>" + h(body) + "</pre>"
        ("<h4>#{h(header)}</h4>#{pre_body}").html_safe
      end
    link.html_safe
  end

  # Create an element that opens a dropdown when it's
  # hovered over.
  def hover_dropdown(header, options = {}, &block)
    @hover_dropdown_div_ids ||= 0
    @hover_dropdown_div_ids += 1
    target_id = "hover_div_#{@hover_dropdown_div_ids}"
    options[:target] = "##{target_id}"
    options[:style] = "display:inline-block"
    dropdown_class = "hover_dropdown "
    dropdown_class += options.delete(:dropdown_class).to_s
    options_setup("hover_open", options)
    atts = options.to_html_attributes
    html = "<span #{atts}>\n".html_safe +
           link_to(h(header), "#") +
            "<div id=#{target_id} class=\"#{dropdown_class}\" style=\"display:none\">\n".html_safe +
            capture(&block) +
            "</div></span>".html_safe
    return html
  end

  # Create tab bars in the interface.
  # Content is provided with a block.
  # [options] A hash of html options for the tab bar structure.
  # Usage:
  #  <% build_tabs do |tb| %>
  #    <% tb.tab "First Tab" do %>
  #       <h1>First tab contents</h1>
  #       More contents.
  #    <% end %>
  #    <% tb.tab "Second Tab" do %>
  #       Wow! Even more contents!
  #    <% end %>
  #  <% end %>
  #
  def build_tabs(options = {}, &block)
    bar = TabBuilder.new

    options[:class] ||= ""
    options[:class] +=  " tabs"

    atts = options.to_html_attributes

    capture(bar,&block)  #Load content into bar object

     html =
       "<div #{atts}>".html_safe +
       bar.tab_titles +
       bar.tab_divs +
       "</div>".html_safe

     return html
   end

  ############################################################
  #
  # Utility class for the build_tabs method (see above).
  #
  #############################################################
  class TabBuilder #:nodoc:

    def initialize #:nodoc:
      @tab_titles = "".html_safe
      @tab_divs   = "".html_safe
    end

    def tab_titles #:nodoc:
      ("<ul>\n" + @tab_titles + "\n</ul>\n").html_safe
    end

    attr_reader :tab_divs #:nodoc:

    # This creates an individual tab, it either takes a block and/or a partial as an option (:partial => "partial")
    def tab(name, &block)
      capture   = eval("method(:capture)", block.binding)
      random_id = rand(1000000).to_s
      @tab_titles += "<li><a href=\"#tb_#{random_id}\">#{name}</a></li>".html_safe


      ###########################################
      # tab content div.                        #
      #                                         #
      # This can be either a partial or a block #
      ###########################################
      @tab_divs += "<div id=\"tb_#{random_id}\">\n".html_safe +
                   capture.call(&block) +
                   "</div>\n".html_safe
      return "" # in case invoked with <%= instead <%
    end
  end


  # Create accordion menus in the interface.
  # Content is provided with a block.
  # [options] A hash of html options for the accordion structure.
  # Usage:
  #  <% build_accordion do |acc| %>
  #    <% acc.section "Section Header" do %>
  #       <h1>First section contents</h1>
  #       More contents.
  #    <% end %>
  #    <% acc.section "Section Two" do %>
  #       Wow! Even more contents!
  #    <% end %>
  #  <% end %>
  #
  def build_accordion(options = {}, &block)
    options[:class] ||= ""
    options[:class] +=  " accordion"

    atts = options.to_html_attributes

    content = capture(AccordionBuilder.new, &block)

    html = "<div #{atts}>".html_safe +
           content +
           "</div>".html_safe
    return html
  end

  ############################################################
  #
  # Utility class for the build_accordion method (see above).
  #
  #############################################################
  class AccordionBuilder #:nodoc:

    def section(header, &block) #:nodoc:
      capture     = eval("method(:capture)", block.binding)
      head = "<h3><a href=\"#\">#{header}</a></h3>".html_safe
      body = "<div style=\"display: none\">".html_safe +
             capture.call(&block) +
             "</div>".html_safe
      return head + body
    end

  end

  # Create a tooltip that displays html when mouseovered.
  # Text of the icon is provided as an argument.
  # Html to be displayed on mouseover is given as a block.
  def html_tool_tip(text = "<span class=\"action_link\">?</span>".html_safe, options = {}, &block)
    @html_tool_tip_id ||= 0
    @html_tool_tip_id += 1

    html_tool_tip_id = @html_tool_tip_id.to_s # we need a local var in case the block rendered ALSO calls html_tool_tip inside !
    html_tool_tip_id += "_#{Process.pid}_#{rand(1000000)}" # because of async ajax requests

    offset_x = options[:offset_x] || 30
    offset_y = options[:offset_y] || 0

    content           = capture(&block) # here, new calls to html_tool_tip can be made.
    content_class     = options.delete(:tooltip_div_class) || "html_tool_tip"
    content_signature = Digest::MD5.hexdigest(content_class + content)

    # Find out if we've already generated an identical tooltip before...
    @content_sig_cache ||= {}
    if @content_sig_cache[content_signature] # yes we did
       html_tool_tip_id = @content_sig_cache[content_signature]
       content_div = nil
    else # no we haven't
       @content_sig_cache[content_signature] = html_tool_tip_id
       content_div = "<div id=\"html_tool_tip_#{html_tool_tip_id}\" class=\"#{content_class}\">" +
                     h(content) +
                    "</div>"
    end

    # Create tooltip trigger
    result = "<span class=\"html_tool_tip_trigger\" id=\"xsp_#{html_tool_tip_id}\" data-tool-tip-id=\"html_tool_tip_#{html_tool_tip_id}\" data-offset-x=\"#{offset_x}\" data-offset-y=\"#{offset_y}\">"
    result += h(text)
    result += "</span>"

    # Add tooltip content, if it's the first time
    result += content_div if content_div

    result.html_safe
  end

  # Create an overlay dialog box with a link as the button.
  # Content is provided through a block.
  # Options:
  #  [width] width in pixels of the overlay.
  #
  # All other options will be treated at HTML attributes.
  #
  # Usage:
  #  <% overlay_content "Click me" do %>
  #    This content will be in the overlay
  #  <% end %>
  #
  def overlay_content_link(name, options = {}, &block)
    options_setup("overlay_content_link", options)
    options[:href] ||= "#"

    element = options.delete(:enclosing_element) || "div"

    atts = options.to_html_attributes

    content = capture(&block)
    return "" if content.blank?

    html = <<-"HTML"
    <#{element} class="overlay_dialog">
      <a #{atts}>#{h(name)}</a>
      <div class="overlay_content" style="display: none;">#{h(content)}</div>
    </#{element}>
    HTML
    html.html_safe
  end

  # Create a button with a drop down menu
  #
  # Options:
  # [:partial] a partial to render as the content of the menu.
  # [:content_id] id of the menu section of the structure.
  # [:button_id] id of the button itself.
  # All other options are treated as HTML attributes on the
  # enclosing span.
  def button_with_dropdown_menu(title, options={}, &block)
    partial    = options.delete :partial
    content_id = options.delete :content_id
    content_id = "id=\"#{content_id}\"" if content_id
    button_id = options.delete :button_id
    button_id = "id=\"#{button_id}\"" if button_id
    options[:class] ||= ""
    options[:class] +=  " button_with_drop_down"
    if options.delete :open
      options["data-open"] = true
      display_style = "style=\"display: block\" "
    else
      display_style = "style=\"display: none\" "
    end

    content = "".html_safe
    if block_given?
      content += capture(&block)
    end
    if partial
      content += render :partial => partial
    end

    atts = options.to_html_attributes

    html  = "<span #{atts}>" +
            "<a #{button_id} class=\"button_menu\">#{title}</a>" +
            "<div #{content_id} #{display_style} class=\"drop_down_menu\">"
    html  = html.html_safe
    html += content
    html += "</div></span>".html_safe

    return html
  end

  # Create an element that will toggle between hiding and showing another element.
  # The appearance/disappearance can also be animated.
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

    atts = options.to_html_attributes
    return " <#{element_type} #{atts}>#{h(text)}</#{element_type}>".html_safe
  end


  # Create an checkbox that will toggle between hiding and showing another element.
  # The appearance/disappearance can also be animated.
  def show_hide_checkbox(target, options = {})
    options["data-target"] = target

    checked = options.delete(:checked)
    if checked
      options["CHECKED"] = true
    end

    invert = options.delete(:invert)
    if invert
      options["data-invert"] = true
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
    options[:class] +=  " show_toggle_checkbox"

    atts = options.to_html_attributes
    return "<input type=\"checkbox\" #{atts} />".html_safe
  end


end
