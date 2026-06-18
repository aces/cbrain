
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

# Saves the workdir of a CBRAIN task as a userfile.
class BackgroundActivity::SaveTaskWorkdir < BackgroundActivity

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def targets_model
    CbrainTask
  end

  def process(item)
    task  = CbrainTask.where(:bourreau_id => CBRAIN::SelfRemoteResourceId).find(item)
    ok    = task.send(:save_cluster_workdir, self.user_id) # it's a protected method
    return [ true,  nil       ] if   ok
    return [ false, "Skipped" ] if ! ok
  end

end

