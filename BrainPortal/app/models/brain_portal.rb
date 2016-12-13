
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

# This model represents a BrainPortal RAILS app.
class BrainPortal < RemoteResource

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  api_attr_visible :name, :user_id, :group_id, :online, :read_only, :description

  # Returns the same RemoteResourceInfo record has the RemoteResource
  # class, but with some more added information specific to a BrainPortal
  def self.remote_resource_info
    myself = RemoteResource.current_resource
    info = super
    info[:num_cbrain_userfiles]       = Userfile.count
    info[:num_sync_cbrain_userfiles]  = myself.sync_status.count          # number of files currently synchornized locally
    info[:size_sync_cbrain_userfiles] = myself.sync_status.joins(:userfile).sum("userfiles.size")  # their tot size
    info[:num_cbrain_tasks]           = CbrainTask.count                  # total number of tasks
    info[:num_active_cbrain_tasks]    = CbrainTask.where({}).active.count # number of active tasks
    info
  end

  # Returns the same RemoteResourceInfo record has the RemoteResource
  # class, but with some more added information specific to a BrainPortal
  def self.remote_resource_ping
    myself = RemoteResource.current_resource
    info = super
    info[:num_cbrain_userfiles]       = Userfile.count
    info[:num_sync_cbrain_userfiles]  = myself.sync_status.count          # number of files currently synchornized locally
    info[:size_sync_cbrain_userfiles] = myself.sync_status.joins(:userfile).sum("userfiles.size")  # their tot size
    info[:num_cbrain_tasks]           = CbrainTask.count                  # total number of tasks
    info[:num_active_cbrain_tasks]    = CbrainTask.where({}).active.count # number of active tasks
    info
  end

  def self.pretty_type #:nodoc:
    "Portal"
  end

  # Lock the portal
  def lock! #:nodoc:
    self.update_attributes!(:portal_locked => true)
  end

  # Unlock the portal
  def unlock! #:nodoc:
    self.update_attributes!(:portal_locked => false)
  end

end
