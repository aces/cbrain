
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
    doc = HelpDocument.find_by_key(key) || HelpDocument.from_existing_file!(key)
    if doc
      overlay_ajax_link display, doc_path(doc), :class  => "btn btn-primary"
    elsif HelpDocument.can_edit?(current_user)
      overlay_ajax_link display, new_doc_path(:key => key), :class => "btn btn-primary grayed-out"
    end
  end
end
