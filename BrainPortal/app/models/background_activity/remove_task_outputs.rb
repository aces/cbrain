#
# CBRAIN Project
#
# Copyright (C) 2008-2026
# The Royal Institution for the Advancement of Learning
# McGill University
#

# Removes the cached outputs of a CBRAIN task safely from the local cache.
# Must be run on a Bourreau only.
class BackgroundActivity::RemoveTaskOutputs < BackgroundActivity::TerminateTask

  Revision_info = CbrainFileRevision[__FILE__] #:nodoc:

  def process(item)
    super(item)
    
    cbrain_task = CbrainTask.where(:bourreau_id => CBRAIN::SelfRemoteResourceId).find_by(id: item)
    return [false, "Task not found"] unless cbrain_task

    output_userfiles = Userfile.where(task_id: cbrain_task.id).to_a

    if output_userfiles.empty?
      self.addlog("No output userfiles registered to erase for task ##{item}.")
      return [true, nil]
    end

    output_userfiles.each do |userfile|
      userfile_id = userfile.id
      
      # Safety check: ensure no downstream task is reading this output file
      output_in_use = CbrainTask.active
                                .where.not(id: cbrain_task.id)
                                .any? { |t| t.params[:interface_userfile_ids]&.include?(userfile_id) }

      if output_in_use
        self.addlog("Skipped output cache erase for '#{userfile.name}' (ID: #{userfile_id}) - asset is in use downstream.")
        next
      end

      userfile.cache_erase
      self.addlog("Deleted cache of output file '#{userfile.name}' (ID: #{userfile_id}) via post-task cleanup policy.")
    end

    [true, nil]
  end

  def prepare_dynamic_items
    populate_items_from_task_custom_filter
  end

end