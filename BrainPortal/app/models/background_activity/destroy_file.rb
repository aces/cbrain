
#
# CBRAIN Project
#
# Copyright (C) 2008-2024
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

# Copy a file
class BackgroundActivity::DestroyFile < BackgroundActivity

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  validates_dynamic_bac_presence_of_option :userfile_custom_filter_id

  def pretty_name
    "Destroy files"
  end

  def process(item)
    userfile     = Userfile.find(item)
    ok           = userfile.destroy
    return [ true,  "Destroyed" ] if   ok
    return [ false, "Skipped"   ] if ! ok
  end

  def prepare_dynamic_items
    populate_items_from_userfile_custom_filter
  end

end

