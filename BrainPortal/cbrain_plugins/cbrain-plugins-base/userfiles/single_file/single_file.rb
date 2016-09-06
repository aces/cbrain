
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

require 'fileutils'

# Represents a single file uploaded to the system (as opposed to a FileCollection).
class SingleFile < Userfile

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  validates :type, :subclass => { :root_class => SingleFile }

  before_create :set_num_files_to_one

  def self.valid_file_classes #:nodoc:
    @valid_file_classes ||= [SingleFile] + SingleFile.descendants
  end

  def pretty_type #:nodoc:
    self.class.pretty_type + (name =~ /(\.gz|\.Z|\.gz2)\z/i ? " (compressed)" : "")
  end

  # Forces calculation and setting of the size attribute.
  def set_size!
    self.size = self.list_files.inject(0){ |total, file_entry|  total += file_entry.size }
    self.save!

    true
  end

  def set_num_files_to_one #:nodoc:
    self.num_files ||= 1
  end

end
