#
# CBRAIN Project
#
# Copyright (C) 2008-2026
# The Royal Institution for the Advancement of Learning
# McGill University
#

# Removes the cached inputs of a CBRAIN task safely from the local cache.
# Must be run on a Bourreau only.
class BackgroundActivity::RemoveTaskInputs < BackgroundActivity::TerminateTask

  Revision_info = CbrainFileRevision[__FILE__] #:nodoc:

  def process(item)
    super(item)
    
    cbrain_task = CbrainTask.where(:bourreau_id => CBRAIN::SelfRemoteResourceId).find_by(id: item)
    return [false, "Task not found"] unless cbrain_task

    input_userfile_ids = cbrain_task.params[:interface_userfile_ids] || []
    
    input_userfile_ids.each do |userfile_id|
      userfile = Userfile.find_by(id: userfile_id)
      next unless userfile

      # Safety check: skip if another active task relies on this exact input
      file_in_use = CbrainTask.active
                              .where.not(id: cbrain_task.id)
                              .any? { |t| t.params[:interface_userfile_ids]&.include?(userfile_id) }

      if file_in_use
        self.addlog("Skipped cache erase for '#{userfile.name}' (ID: #{userfile_id}) - asset is currently in use.")
        next
      end

      userfile.cache_erase
      self.addlog("Deleted cache of input file '#{userfile.name}' (ID: #{userfile_id}) via post-task cleanup policy.")
    end

    [true, nil]
  end

  def prepare_dynamic_items
    populate_items_from_task_custom_filter
  end

end