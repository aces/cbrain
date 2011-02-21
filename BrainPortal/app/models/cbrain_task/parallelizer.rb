
#
# CBRAIN Project
#
# Parallelizer task model
#
# Original author: Pierre Rioux
#
# $Id$
#

#A subclass of PortalTask to launch parallelize other tasks.
class CbrainTask::Parallelizer < PortalTask

  Revision_info="$Id$"

  def self.properties #:nodoc:
    { :no_presets => true }
  end

  # Creates and launch a parallelizer for a set of other CbrainTasks
  # supplied in +tasklist+.
  def self.create_from_task_list(tasklist = [], group_size = 2) #:nodoc:
 
    return "" if tasklist.empty?

    unless tasklist.all? { |t| t.status == 'Standby' }
      cb_error "Trying to parallelize a list of tasks that are NOT in Standby state?!?"
    end
    unless tasklist.all? { |t| t.bourreau_id == tasklist[0].bourreau_id }
      cb_error "Trying to parallelize a list of tasks that are NOT all on the same Bourreau?!?"
    end

    # Create a ToolConfig if needed; this just saves the sysadmin some time,
    # since they are rather dummy.
    tool_id     = self.tool.id
    bourreau_id = tasklist[0].bourreau_id
    tc = ToolConfig.find_by_tool_id_and_bourreau_id(tool_id,bourreau_id)
    if !tc
      tc = ToolConfig.create!(
        :tool_id         => tool_id,
        :bourreau_id     => bourreau_id,
        :ncpus           => 512,
        :env_array       => [],
        :script_prologue => "",
        :description =>
          "Standard CBRAIN Parallelizer\n" +
          "\n" +
          "Automatically created by #{self} rev. #{self.revision_info.svn_id_rev}.\n" +
          "Note that the suggested number of CPUs defined here is not in fact used.\n" +
          "Instead, the parallelism factor is determined by the parallelized program's\n" +
          "own configuration.\n"
      )
    end

    # Destructively go through the task list and build parallelizers
    desttasklist = tasklist.dup # we'll destroy THIS array, and leave the original intact
    num_parallelizers = 0
    while desttasklist.size > 0

      subtasklist  = desttasklist[0,group_size]           # first group_size tasks
      desttasklist = desttasklist[group_size,99999] || [] # destructively, here's the rest

      # For groups of one, we just launch normally
      if subtasklist.size < 2 || group_size < 2
        subtasklist.each do |task|
          task.status = 'New'
          task.save!
        end
        next # may end the destructive loop, or continue it if we were grouping them all one by one
      end

      # Create the parallelizer
      first = subtasklist[0]
      description = "Parallelizer ##{num_parallelizers+1} for #{first.name} x #{subtasklist.size}"
      if subtasklist.size < tasklist.size
        description += "\nThis task runs a subset of #{subtasklist.size} out of a larger batch of #{tasklist.size} tasks."
      end
      tasks_ids_enabled = {}
      subtasklist.map(&:id).each { |id| tasks_ids_enabled[id.to_s] = "1" }
      parallelizer = self.new(
        :description    => description,
        :user_id        => first.user_id,
        :group_id       => first.group_id,
        :bourreau_id    => first.bourreau_id,
        :status         => 'New',
        :params         => { :task_ids_enabled => tasks_ids_enabled },
        :launch_time    => first.launch_time,
        :tool_config_id => tc.id
      )

      # Add prereqs: the parallelizer can only start once the
      # subtasks are configured
      subtasklist.each do |task|
        parallelizer.add_prerequisites_for_setup(task, 'Configured')
      end

      # Launch the parallelizer
      parallelizer.save!
      num_parallelizers += 1

      # Launch the subtasks with prerequisites and the 'Configure Only' meta option
      subtasklist.each do |task|
        task.add_prerequisites_for_post_processing(parallelizer, 'Completed')
        task.status = "New" # trigger them to start
        task.meta[:configure_only]=true
        task.save!
      end
    end

    if num_parallelizers > 1
      "Launched #{num_parallelizers} Parallelizer tasks (covering a total of #{tasklist.size} tasks)."
    else
      "Launched a Parallelizer task (covering a total of #{tasklist.size} tasks)."
    end

  end

end

