
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

# View helpers for creating ajax widgets.
module AjaxWidgetHelper

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  include JavascriptOptionSetup

  ###############################################################
  # Creates an html element which will have its content updated
  # with an ajax call to the url specified in the options hash
  #
  # Options:
  # [:element] the type of element to generate. Defaults to "div".
  # All other options will be treated as HTML attributes.
  #
  # Example:
  #
  # <% ajax_element( "/data_providers", :element => "span", :class => "left right center") do %>
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

    interval = options.delete(:interval)
    if interval
      options["data-interval"] = h interval
    end

    scroll_bottom = options.delete(:scroll_bottom)
    if scroll_bottom
      options["data-scroll-bottom"] = h scroll_bottom
    end

    options_setup("ajax_element", options)

    options["data-url"] = url

    #This builds an html attribute string from the html_opts hash
    atts = options.to_html_attributes

    initial_content = capture(&block) if block_given?
    initial_content ||= html_colorize("Loading...")

    html = "<#{element} #{atts}>"
    html += h(initial_content)
    html += "</#{element}>"

    html.html_safe
  end

  # This doesn't seem to be used anymore? PR OCT 2015
  def ajax_refresh_link(text, target, options = {}) #:nodoc:
    options["data-target"] = target

    options[:class] ||= ""
    options[:class] +=  " ajax_element_refresh_button"

    link_to text, "#", options
  end

  # Request some js through ajax to be run on the current page.
  def script_loader(url, options = {})
    options["data-url"] = url

    options[:class] ||= ""
    options[:class] +=  " script_loader"

    # This builds an html attribute string from the html_opts hash
    atts = options.to_html_attributes

    "<div #{atts}></div>".html_safe
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
  # replace can be used to specify an id of an html element to replace
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
    atts = html_opts.to_html_attributes


    initial_content=capture(&block)+((render partial unless !partial) || "")

    html = "<#{element} data-url=\"#{url}\" #{atts}>".html_safe +
            initial_content +
           "</#{element}>".html_safe

    return html
  end

  # Creates a text field that will sends an ajax
  # request to +url+ when the enter key is hit. The current
  # text is sent as parameter +name+.
  #
  # Options:
  # [:default] initial text in the field.
  # [:datatype] the datatype expected from the request (HTML, XML, script...).
  # [:method] HTTP method to use for the request.
  # [:target] selector indicating where the response data should be place in the
  #           page.
  # All other options treated as HTML attributes.
  def ajax_search_box(name, url, options = {})
    options_setup("search_box", options)

    options["data-url"] = url
    default_value       = options.delete(:default)

    text_field_tag(name, default_value, options)
  end

  # Create an overlay dialog box with a link as the button.
  # Content is provided through an ajax request.
  # +options+ same as for link_to
  def overlay_ajax_link(name, url, options = {})
    options[:datatype] ||= "html"
    options[:overlay] = true

    ajax_link h(name.to_s), url, options
  end

  # Create a link that will submit an ajax_request to +url+
  #
  # Creates a text field that will send an ajax
  # request to +url+ when the enter key is hit. The current
  # text is sent as parameter +name+.
  #
  # Options:
  # [:datatype] the datatype expected from the request (HTML, XML, script...).
  # [:method] HTTP method to use for the request.
  # [:target] selector indicating where the response data should be place in the
  #           page.
  # All other options treated as HTML attributes.
  def ajax_link(name, url, options = {})
    options_setup("ajax_link", options)
    options[:remote] = true

    link_to h(name.to_s), url, options
  end

  # Create a link that will submit an ajax request. The
  # difference between this and ajax_link is that it is assumed
  # this link will be removing/updating something in the page, and
  # thus has some options for manipulating the page prior to sending
  # the request.
  #
  # Aside from the options for ajax_link there are:
  # [:loading_message] text with which to update the target elements
  #                prior to sending the request.
  # [:confirm] Confirm message to display before sending the request.
  def delete_button(name, url, options = {})
    options[:method]   ||= 'DELETE'
    options[:datatype] ||= 'script'

    ajax_link h(name.to_s), url, options
  end

  # A select box that will update the page onChange.
  #
  # Options:
  # [:datatype] the datatype expected from the request (HTML, XML, script...).
  # [:method] HTTP method to use for the request.
  # [:target] selector for elements to update prior to or after the
  #          the request is sent.
  # [:loading_message] text with which to update the target elements
  #                prior to sending the request.
  # All other options treated as HTML attributes.
  def ajax_onchange_select(name, url, option_tags, options = {})
    options_setup("request_on_change", options)

    options["data-url"] = url

    select_tag(name, option_tags, options)
  end

end
