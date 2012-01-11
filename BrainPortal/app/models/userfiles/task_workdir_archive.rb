
#
# CBRAIN Project
#
# TaskWorkdirArchive model
#
# Original author: Pierre Rioux
#

class TaskWorkdirArchive < SingleFile

  Revision_info=CbrainFileRevision[__FILE__]

  has_viewer :task_workdir_archive
  
  def self.file_name_pattern #:nodoc:
    /^CbrainTask_Workdir_\d+\.tar\.gz$/i
  end

  def self.pretty_type #:nodoc:
    "Task Workdir Archive"
  end
  
end
