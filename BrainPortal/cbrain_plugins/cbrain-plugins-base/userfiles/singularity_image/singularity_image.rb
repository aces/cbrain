
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

# This model represents a single file containing a Singularity container image.
class SingularityImage < FilesystemImage

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  has_viewer :name => 'Image Info', :partial  => :info, :if => :is_viewable?

  def self.file_name_pattern #:nodoc:
    /\.s?img\z|\.sif\z/i
  end

  def is_viewable? #:nodoc:
    if ! self.has_apptainer_support?
      return [ "The local portal doesn't support inspecting Apptainer (aka Singularity) images." ]
    elsif ! self.is_locally_synced?
      return [ "Apptainer (aka Singularity) image file not yet synchronized" ]
    else
      true
    end
  end

  def has_apptainer_support? #:nodoc:
    self.class.has_apptainer_support?
  end

  def self.apptainer_executable  #:nodoc:
    @_executable ||= RemoteResource.current_resource.apptainer_executable_name.presence || "apptainer"
  end

  # Detects if the system has the Apptainer command.
  # Singularity command is still supported on best effort basis
  # Caches the result in the class so it won't need to
  # be detected again after the first time, for the life
  # of the current process.
  def self.has_apptainer_support? #:nodoc:
    return @_has_apptainer_support if ! @_has_apptainer_support.nil?
    out = IO.popen("bash -c 'type -p #{apptainer_executable}'","r") { |f| f.read }
    @_has_apptainer_support = out.present?
  end

end
