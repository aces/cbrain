
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
    true
  end

  def self.get_default_args(params = {}, saved_args = {})
    params[:setup_delay]   = 0
    params[:cluster_delay] = 0
    params[:postpro_delay] = 0

    params[:setup_crash]   = false
    params[:postpro_crash] = false

    params[:num_copies]    = 1
    params
  end

  #See DrmaaTask.
  def self.launch(params) 
    
    user_id    = params[:user_id]    || 0
    file_ids   = params[:file_ids]   || []
    num_copies = (params[:num_copies] || 1).to_i

    user       = User.find(user_id)
    numfiles   = file_ids.size
    files_hash = file_ids.index_by { |id| "F#{id}" }
    num_copies = 100 if num_copies > 100

    CBRAIN.spawn_with_active_records_if(num_copies > 3, user, "Diagnostics Launcher") do
      num_copies.times do |i|
        task             = DrmaaDiagnostics.new
        task.description = "Diagnostics with #{numfiles} files" + (num_copies > 1 ? ", copy #{i+1}." : ".")
        task.params      = {
                              :files_hash    => files_hash,
                              :setup_delay   => params[:setup_delay],
                              :cluster_delay => params[:cluster_delay],
                              :postpro_delay => params[:postpro_delay],
                              :setup_crash   => params[:setup_crash],
                              :postpro_crash => params[:postpro_crash],
                              :copy_number   => i
                           }
        task.user_id     = user_id
        task.save
      end
    end

    "Launched #{num_copies} Diagnostics tasks with #{numfiles} files each."
  end

end

