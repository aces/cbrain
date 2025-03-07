
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

# Copy a file, but the new copy is not left registered in the DB
class BackgroundActivity::CopyFileAndUnregister < BackgroundActivity::CopyFile

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def process(item)
    ok, userfile_id = super # CopyFile can return the ID or a string message
    return [ ok, userfile_id ] if userfile_id.is_a?(String) # a message
    userfile = Userfile.find(userfile_id)
    userfile.unregister
    [ true, nil ]
  end

end

