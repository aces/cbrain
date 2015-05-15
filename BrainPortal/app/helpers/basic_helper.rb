
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

# Basic view helpers. Mainly text manipulation and icons.
module BasicHelper

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Sets the text to be displayed in the title bar when a given view is rendered.
  def title(page_title)
    content_for(:title)  { ' - ' + page_title }
  end

  # Replacement for old rails helper.
  def error_messages_for(object, options = {})
    return "" unless object.present?
    options[:object] = object
    render :partial => "shared/error_messages", :locals => options
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

  # Reduces a string to the length specified by +length+.
  def crop_text_to(length, string)
    return ""     if string.blank?
    return h(string) if string.length <= length
    return h(string[0,length-3]) + "...".html_safe
  end

  # Produces a pretty 'delete' symbol (used mostly for removing
  # active filters)
  def delete_icon
    "<span class=\"delete_icon\">&otimes;</span>".html_safe
  end

  # Produces a pretty symbol for archived FileCollection
  def archived_icon(color="purple")
    "<span style=\"color:#{color}\" class=\"bold_icon\">A</span>".html_safe
  end

end

