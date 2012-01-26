
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

# A simple monitoring task that doesn't do anything at all.
# Can be use to track other tasks through prerequisites.
class CbrainTask::SimpleMonitor < ClusterTask

  Revision_info=CbrainFileRevision[__FILE__]

  include RestartableTask
  include RecoverableTask

  # See CbrainTask.txt
  def setup #:nodoc:
    params       = self.params
    true
  end

  # See CbrainTask.txt
  def cluster_commands #:nodoc:
    params       = self.params
    nil # NO cluster commands
  end
  
  # See CbrainTask.txt
  def save_results #:nodoc:
    params       = self.params
    true
  end

end

