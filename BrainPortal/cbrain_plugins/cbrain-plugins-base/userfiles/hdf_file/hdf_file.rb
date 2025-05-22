
#
# CBRAIN Project
#
# Copyright (C) 2008-2025
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

# Model for Hierarchical Data Format (HDF) files.
class HdfFile < SingleFile

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  has_viewer :name => 'HDF stat', :partial => :hdf_stat, :if =>
                Proc.new { |u| u.class.has_h5stat?  &&
                               u.is_locally_synced? &&
                             (!u.is_compressed? || u.compressed_error) }

  has_viewer :name => 'HDF ls', :partial => :hdf_ls, :if =>
                Proc.new { |u| u.class.has_h5stat?  &&
                               u.is_locally_synced? &&
                             (!u.is_compressed? || u.compressed_error) }

  def self.file_name_pattern #:nodoc:
    /\.(hdf|hdf4|hdf5|he4|he5|h4|h5)\z/i
  end

  def self.pretty_type #:nodoc:
    "HDF File"
  end

  def self.has_h5stat? #:nodoc:
    system("bash","-c","which h5stat >/dev/null 2>&1")
  end

  def self.has_h5ls? #:nodoc:
    system("bash","-c","which h5ls >/dev/null 2>&1")
  end

  def is_compressed? #:nodoc:
    self.name =~ /\.(gz|z|bz2)\z/i
  end

  # Return the message that will be render
  # in place of the viewer if the file is compressed.
  def compressed_error
    ["The file is compressed, so it cannot be viewed."]
  end

end

