
#
# CBRAIN Project
#
# Copyright (C) 2008-2023
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

# Model for filesystem files in SquashFS format.
class SquashfsFile < SingleFile

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  has_viewer :name => 'SquashFS Filesystem', :partial => :squashfs_file, :if => :is_viewable?

  def self.file_name_pattern #:nodoc:
    /\.(sqs|squashfs|sqfs|sfs)\z/i
  end

  def self.pretty_type #:nodoc:
    "SquashFS Filesystem File"
  end

  def is_viewable? #:nodoc:
    if ! self.has_unsquashfs_support?
      return [ "The local portal doesn't support inspecting SquashFS images." ]
    elsif ! self.is_locally_synced?
      return [ "The SquashFS image file is not yet synchronized" ]
    else
      true
    end
  end

  def has_unsquashfs_support? #:nodoc:
    self.class.has_unsquashfs_support?
  end

  # Detects if the system has the 'unsquashfs' command.
  # Caches the result in the class so it won't need to
  # be detected again after the first time, for the life
  # of the current process.
  def self.has_unsquashfs_support? #:nodoc:
    return @_has_unsquashfs_support if ! @_has_unsquashfs_support.nil?
    out = IO.popen("bash -c 'type -p unsquashfs'","r") { |f| f.read }
    @_has_unsquashfs_support = out.present?
  end

end
