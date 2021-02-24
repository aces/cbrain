
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

# Generic model for text files.
class TextFile < SingleFile

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  has_viewer :name     => 'Text File',
             :partial  => :text_file,
             :if       =>  Proc.new { |u, size|
                                          false if !(u.size.present? || size.present?);
                                          size = size.present? ? size.to_i : u.size;
                                          size < 500_000
                                    }

  def self.file_name_pattern #:nodoc:
    /\.txt\z/i
  end

  def is_viewable? #:nodoc:
    userfile_errors = []
    userfile_errors.push("No size available for this file") if self.size.blank?
    userfile_errors.push("File is too large to be viewable (> 500 kB)") if self.size > 500_000
    userfile_errors
  end

end
