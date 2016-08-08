
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

class TaskVmAllocation < ActiveRecord::Base
  
  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  attr_accessible :task_id, :vm_id

  # Automatically register the task's version when new() is invoked.
  def initialize(arguments = {}) #:nodoc:
    super(arguments)
    baserev = Revision_info
    self.addlog("#{baserev.svn_id_file} rev. #{baserev.svn_id_rev}", :caller_level => 3)
  end

end
