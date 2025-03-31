
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

# Destroy a CBRAIN task. Unlike the other DestroyTask, this
# activity can only handle tasks that don't have work directories
# present (it will check for that). This means this activity can
# be executed on the portals or on bourreaux. It will not invoke
# the terminate code, but it will make sure a task is in a non-active
# status.
class BackgroundActivity::DestroyTaskWithoutWorkdir < BackgroundActivity

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def process(item)
    cbrain_task = CbrainTask.find(item)

    if cbrain_task.cluster_workdir.present?
      return [ false, 'HasWorkdir' ]
    end

    if cbrain_task.status != 'New' && CbrainTask::ACTIVE_STATUS.include?(cbrain_task.status)
      return [ false, 'IsActive' ]
    end

    ok = cbrain_task.destroy
    return [ true,  nil         ] if   ok
    return [ false, "Skipped"   ] if ! ok
  end

end

