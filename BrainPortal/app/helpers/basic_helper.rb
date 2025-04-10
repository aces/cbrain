
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
  def title(page_title, sep=' - ')
    content_for(:title)  { sep.html_safe + page_title }
  end

  # Replacement for old rails helper.
  def error_messages_for(object, options = {})
    return "" unless object.present?
    options[:object] = object
    render :partial => "shared/error_messages", :locals => options
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

  # Alternate toggle for session attributes that switch between values 'on' and 'off'
  def set_toggle(old_value)
   old_value == 'on' ? 'off' : 'on'
  end

  # Renders an 'down-and-right' arrow with an indentation proportional to +level+
  def tree_view_icon(level = 0)
    ('&nbsp' * 4 * (level.presence || 0) + '&#x21b3;').html_safe
  end

  # Produces clipboard icon, currently used for copy to clipboard button
  def clipboard_icon
    "<span>&#128203;</span>"
  end

  # Creates a simple svg icon for copy (a square upon another square),
  # akin to Unicode copy symbol but a bit cleaner
  def copy_icon
    '<svg
          width="12" height="12" viewBox="0 0 24 24" fill="none"
          xmlns="http://www.w3.org/2000/svg" style="vertical-align: middle;">
        <rect x="4" y="4" width="14" height="14" rx="2" ry="2"
          fill="#d1d5da" stroke="#6a737d" stroke-width="1.25"/>
        <rect x="7" y="7" width="14" height="14" rx="2" ry="2"
          fill="#d1d5da" stroke="#6a737d" stroke-width="1.25"/> </svg>'
  end

  # Renders 1234567 as 1,234,567
  def number_with_commas(number)
    s = number.to_s
    return s if s !~ /\A\d+\z/ # anything not a series of digits is just returned as is
    s.reverse.gsub(/(\d\d\d)(?=\d)/, '\1,').reverse
  end

  # Checks if the current page is rendered with a specific
  # controller and action; arguments are one or many strings
  # in the format "controller#action" (e.g. "users#show"); the
  # method will return true if the page matches any of the
  # strings. Either controller or action can be left blank to
  # match any controller or action (e.g. "users#" and "#show"),
  # although filtering by action only doesn't seem very useful.
  #
  # This method is mostly to be used in templating code, as like in
  #
  #    <% if page_is?("tasks#index") %>
  def page_is?(*contr_actions)
    Array(contr_actions).any? do |contr_action|
      contr,action = contr_action.split('#')
      (contr.blank? || params[:controller] == contr) && (action.blank? || params[:action] == action)
    end
  end

  # Returns the opposite true/false value of page_is?()
  def page_is_not?(*contr_actions)
    ! page_is?(*contr_actions)
  end

end

