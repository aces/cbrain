
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
# subclasses that are naturally recoverable.
module RecoverableTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Just returns true; it's the responsibility
  # of the CbrainTask developer to write the
  # setup() method such that it recovers from
  # failure naturally.
  def recover_from_setup_failure
    true
  end

  # Just returns true; it's the responsibility
  # of the CbrainTask developer to write the
  # bash commands returned by the cluster_commands() method
  # such that they recover from failure naturally.
  def recover_from_cluster_failure
    true
  end

  # Just returns true; it's the responsibility
  # of the CbrainTask developer to write the
  # save_results() method such that it recovers from
  # failure naturally.
  def recover_from_post_processing_failure
    true
  end

end

