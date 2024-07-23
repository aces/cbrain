
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

# Restart a CBRAIN task. This is the CBRAIN operation
# that trigger restarting code at three possible
# stages of an already Completed task. The
# value of options[:atwhat] must be one of
# 'Setup', 'Cluster' or 'PostProcess'
class BackgroundActivity::RestartTask < BackgroundActivity

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  before_save :must_be_on_bourreau!

  def process(item)
    task       = CbrainTask.where(:bourreau_id => CBRAIN::SelfRemoteResourceId).find(item)
    atwhat     = options[:atwhat]
    old_status = task.status
    ok         = task.restart(atwhat)
    task.addlog("New status: #{task.status}") if ok && (old_status != task.status)
    return [ true,  "Restarting" ] if   ok
    return [ false, "Skipped"    ] if ! ok
  end

  def after_last_item
    pool = WorkerPool.find_pool(BourreauWorker)
    pool.wake_up_workers
    true
  rescue => ex
    Rails.log.debug "AfterLastItem of #{self.class} raised #{ex.class}: #{ex.message}"
  end

end

