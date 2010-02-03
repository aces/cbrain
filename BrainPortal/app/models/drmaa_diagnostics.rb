
#
# CBRAIN Project
#
# DrmaaDiagnostics model as ActiveResource
#
# Original author: Pierre Rioux
#
# $Id$
#

#A subclass of DrmaaTask to launch diagnostics.
class DrmaaDiagnostics < DrmaaTask

  Revision_info="$Id$"

  #See DrmaaTask.
  def self.has_args?
    false
  end

  #See DrmaaTask.
  def self.launch(params) 
    
    file_ids   = params[:file_ids] || []
    numfiles   = file_ids.size
    files_hash = file_ids.index_by { |id| id }

    task             = DrmaaDiagnostics.new
    task.description = "Diagnostics with #{numfiles} files"
    task.params      = { :files_hash => files_hash }
    task.user_id     = params[:user_id]
    task.save

    "Launched Diagnostics task with #{numfiles}"
  end

end

