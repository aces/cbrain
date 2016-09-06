
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

# Model for archives of CBRAIN task work directories.
class TaskWorkdirArchive < TarArchive

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # The association linking back to the task itself.
  has_one        :archived_task, :class_name  => 'CbrainTask',
                                 :foreign_key => :workdir_archive_userfile_id,
                                 :dependent   => :nullify

  has_viewer     :name => 'CBRAIN Workdir Task Archive', :partial => :task_workdir_archive

  before_destroy :before_destroy_adjust_task

  def self.file_name_pattern #:nodoc:
    /\ACbrainTask_Workdir_[\w\-]+\.tar\.gz\z/i
  end

  def self.pretty_type #:nodoc:
    "Task Workdir Archive"
  end

  def before_destroy_adjust_task #:nodoc:
    # Find original task
    task     = self.archived_task rescue nil
    return true unless task

    # Adjust/save task ; use update_column in order not to change the updated_at value
    task.update_column(:workdir_archived, false)
    return true
  end

end
