
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

# Model for archive files in .tar format.
class TarArchive < SingleFile

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  has_viewer :name => 'TAR Archive', :partial => :tar_archive

  def self.file_name_pattern #:nodoc:
    /\.tar(\.gz)?\z|\.tgz\z/i
  end

  def self.pretty_type #:nodoc:
    "Tar Archive"
  end

end
