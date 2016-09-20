
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

# Helpers for DataProvider views.
module DataProvidersHelper

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

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

  # Creates a link called "(info)" that presents as an overlay
  # the set of descriptions for the data providers given in argument.
  def overlay_data_providers_descriptions(data_providers = nil)
    all_descriptions = data_providers_descriptions(data_providers)
    link =
       overlay_content_link("(info)", :enclosing_element => 'span') do
         all_descriptions.html_safe
       end
    link.html_safe
  end

  # Returns a description of each DP
  def data_providers_descriptions(data_providers = nil)
    data_providers ||= DataProvider.find_all_accessible_by_user(current_user).all
    paragraphs = data_providers.collect do |dp|
      <<-"HTML"
        <strong>#{h(dp.name)}</strong>
        <p>
        #{dp.description.blank? ? "(No description)" : h(dp.description.strip)}
        </p>
      HTML
    end
    all_descriptions = <<-"HTML"
      #{paragraphs.join("")}
    HTML
    return all_descriptions.html_safe
  end

  def class_param_for_name(name, klass=Userfile) #:nodoc:
    matched_class = klass.descendants.unshift(klass).find{ |c| name =~ c.file_name_pattern }

    if matched_class
      "#{matched_class.name}-#{name}"
    else
      nil
    end
  end

end

