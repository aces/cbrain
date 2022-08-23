
#
# CBRAIN Project
#
# Copyright (C) 2008-2020
# The Royal Institution for the Advancement of Learning
# McGill University  in collaboration with Cuba Center for NeuroSciences (CNEURO), Neuro-informatic Department
# development: tperezdevelopment@gmail.com
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

# Model for archive files in .zip format.
class ZipArchive < SingleFile

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  has_viewer :name => 'Zip Archive', :partial => :zip_archive

  def self.file_name_pattern #:nodoc:
    /\.zip\z/i
  end

  def self.pretty_type #:nodoc:
    "Zip Archive"
  end

end
