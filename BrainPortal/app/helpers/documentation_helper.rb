
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

# Helper to add documentation (help) elements
module DocumentationHelper

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Returns HTML markup for an help button which, when clicked, will
  # display the documentation page corresponding to +key+.
  # If no help is available for +key+, this function returns nothing.
  # The core admin can modify the documentation displayed through the
  # shown documentation page.
  # See the help_document views for more details.
  def help_button(key, display = "Help")
    doc = HelpDocument.find_by_key(key)

    if doc
      link_to display, '#', { :data => { :toggle => "modal", :target => "#dynamic-help-modal", :id => doc.id, :key => key, :url => doc_path(doc) }, :class => "btn btn-primary" }
    else
      link_to display, '#', { :data => { :toggle => "modal", :target => "#dynamic-help-modal", :id => "empty", :key => key, :url => new_doc_path(:key => key) }, :class => "btn btn-primary" }
    end
  end
end
