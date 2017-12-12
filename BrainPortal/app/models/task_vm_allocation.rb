
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

# This object keeps track of the allocations of tasks in VMs. The
# reason for creating a separate object rather than just adding a
# 'vm_id' attribute to ClusterTask is that task allocations are
# created during the task submission process, in method
# scir_cloud.schedule_task_on_vm which is called from scir_cloud.run
# when the task is transitioning from "New" to "Setting Up". The
# bourreau_worker, however, reads the task at the beginning of the
# transitioning process (bourreau_worker.process_task) and saves it at
# the end, which means that the modifications saved on the task during
# the transitioning process are either lost or they just crash
# Rails. The task transitioning mechanism in bourreau_worker may be
# updatable to allow for such task modifications during task
# transitions, but that would be complex and error-prone. Instead,
# creating a simple table to store these allocations sounds simple and
# efficient.
class TaskVmAllocation < ActiveRecord::Base

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

end

