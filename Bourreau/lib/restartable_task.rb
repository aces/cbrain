
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

# Module containing common methods for the ClusterTask
# subclasses that are naturally restartable.
module RestartableTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Just returns true; it's the responsibility
  # of the CbrainTask developer to write the
  # setup() method such that it can be restarted
  # naturally.
  def restart_at_setup
    true
  end

  # Just returns true; it's the responsibility
  # of the CbrainTask developer to write the
  # bash commands returned by the cluster_commands() method
  # such that they can be restarted naturally.
  def restart_at_cluster
    true
  end

  # Just returns true; it's the responsibility
  # of the CbrainTask developer to write the
  # save_results() method such that it can be restarted
  # naturally.
  def restart_at_post_processing
    true
  end

end

