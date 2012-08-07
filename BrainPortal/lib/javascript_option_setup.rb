
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

module JavascriptOptionSetup #:nodoc:

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  private
  
  # Set up options for rich ui or ajax elements.
  def options_setup(element_class, options)
    options[:class] ||= ""
    options[:class] +=  " #{element_class}"
    
    url = options.delete(:url)
    if url
      options["data-url"] = url
    end
    
    data_type = options.delete(:datatype)
    if data_type
      options["data-type"] = data_type.to_s.downcase
    end
    
    method = options.delete(:method)
    if method
      options["data-method"] = method.to_s.upcase
    end
    
    target = options.delete(:target)
    if target
      options["data-target"] = target
    end
    
    remove_target = options.delete(:remove_target)
    if remove_target
      options["data-remove-target"] = remove_target
    end
    
    update_text = options.delete(:loading_message)
    if update_text
      options["data-loading-message"] = update_text
    end
    
    update_text_target = options.delete(:loading_message_target)
    if update_text_target
      options["data-loading-message-target"] = update_text_target
    end
    
    overlay = options.delete(:overlay)
    if overlay && overlay.to_s.downcase != "false"
      options["data-target"] = "__OVERLAY__"
    end
    
    confirm = options.delete(:confirm)
    if confirm
      options["data-confirm"] = confirm
    end
    
    width = options.delete(:width)
    if width
      options["data-width"] = width
    end
    
    height = options.delete(:height)
    if height
      options["data-height"] = height
    end
    
    error_message = options.delete(:error_message)
    if error_message
      options["data-error"] = h(error_message)
    end
    
    replace = options.delete(:replace)
    if replace
      options["data-replace"] = replace
    end
  end
  
end

