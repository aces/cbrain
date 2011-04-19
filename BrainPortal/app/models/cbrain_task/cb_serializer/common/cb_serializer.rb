
#
# CBRAIN Project
#
# Serializer task model
#
# Original author: Pierre Rioux
#
# $Id$
#

class CbrainTask::CbSerializer

  # Creates and launch a set of Serializers for a set of other
  # CbrainTasks supplied in +tasklist+. All the tasks in +tasklist+
  # are assumed to already have been created with status 'Standby'.
  #
  # Returns an array of three elements:
  #
  # * A message about how things went
  # * An array of the Serializer task objects
  # * An array of the leftover task objects not serialized (if any)
  #
  # Supported options:
  #
  #   :group_size               => group that many task per Serializer
  #   :initial_rank             => rank counter for task batching
  #   :subtask_level            => level of subtasks in task batch, default 1
  #   :serializer_level         => level of Serializers in task batch, default 0
  #   :subtask_start_state      => subtask status once serialized, default 'New'
  #   :serializer_start_state   => Serializer status once created, default 'New'
  def self.create_from_task_list(tasklist = [], options = {}) #:nodoc:
 
    return [ "",[], [] ] if tasklist.empty?

    options    = { :group_size => options } if options.is_a?(Fixnum) # old API
    group_size = options[:group_size] || 2

    unless tasklist.all? { |t| t.status == 'Standby' }
      cb_error "Trying to serialize a list of tasks that are NOT in Standby state?!?"
    end
    unless tasklist.all? { |t| t.bourreau_id == tasklist[0].bourreau_id }
      cb_error "Trying to serialize a list of tasks that are NOT all on the same Bourreau?!?"
    end

    # Create a ToolConfig if needed; this just saves the sysadmin some time,
    # since they are rather dummy.
    tool        = self.tool
    cb_error    "Not Tool yet configured for the #{self} class ?!?" unless tool
    tool_id     = tool.id
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
          "Standard CBRAIN Serializer\n" +
          "\n" +
          "Automatically created by #{self} rev. #{self.revision_info.svn_id_rev}.\n" +
          "Note that the suggested number of CPUs defined here is not in fact used.\n" +
          "Instead, the serialization factor is determined by the Serializer program's\n" +
          "creation context.\n"
      )
    end

    # Destructively go through the task list and build Serializers
    desttasklist        = tasklist.dup # we'll destroy THIS array, and leave the original intact
    serializer_tasks    = [] # serializer tasks
    normal_tasks        = [] # tasks launched normally, independently
    num_serial          = 0 # tasks under serializer control
    rank                = options[:initial_rank]             || 0 # global counter for all tasks in the batch
    level_task          = options[:subtask_level]            || 1
    level_serial        = options[:serializer_level]         || 0
    subtask_start_state = options[:subtask_start_state]      || 'New'
    serial_start_state  = options[:serializer_start_state]   || 'New'

    while desttasklist.size > 0

      subtasklist  = desttasklist[0,group_size]           # first group_size tasks
      desttasklist = desttasklist[group_size,99999] || [] # destructively, here's the rest

      # For groups of one, we just launch normally
      if subtasklist.size < 2 || group_size < 2
        subtasklist.each do |task|
          task.status = subtask_start_state
          task.rank   = rank       unless task.rank; rank += 1
          task.level  = level_task unless task.level
          task.save!
          normal_tasks << task
        end
        next # may end the destructive loop, or continue it if we were grouping them all one by one
      end

      # Create the Serializer
      first = subtasklist[0]
      description = "Serializer ##{serializer_tasks.size+1} for #{first.name} x #{subtasklist.size}"
      if subtasklist.size < tasklist.size
        description += "\nThis task runs a subset of #{subtasklist.size} out of a larger batch of #{tasklist.size} tasks."
      end
      tasks_ids_enabled = {}
      subtasklist.map(&:id).each { |id| tasks_ids_enabled[id.to_s] = "1" }
      serializer = self.new(
        :description    => description,
        :user_id        => first.user_id,
        :group_id       => first.group_id,
        :bourreau_id    => first.bourreau_id,
        :status         => serial_start_state,
        :params         => { :task_ids_enabled => tasks_ids_enabled },
        :launch_time    => first.launch_time,
        :rank           => rank,
        :level          => level_serial,
        :tool_config_id => tc.id
      )
      rank += 1

      # Add prereqs: the Serializer can only start once the
      # subtasks are configured
      subtasklist.each do |task|
        serializer.add_prerequisites_for_setup(task, 'Configured')
      end

      # Launch the Serializer
      serializer.save!
      serializer_tasks << serializer
      num_serial       += subtasklist.size

      # Launch the subtasks with prerequisites and the 'Configure Only' meta option
      subtasklist.each do |task|
        task.add_prerequisites_for_post_processing(serializer, 'Completed')
        task.status = subtask_start_state # trigger them to start
        task.rank   = rank       unless task.rank; rank += 1
        task.level  = level_task unless task.level
        task.meta[:configure_only]=true
        task.save!
      end
    end

    messages = ""

    if serializer_tasks.size > 1
      messages += "Launched #{serializer_tasks.size} Serializer tasks (covering a total of #{num_serial} tasks).\n"
    elsif serializer_tasks.size == 1
      messages += "Launched a Serializer task (covering a total of #{num_serial} tasks).\n"
    end

    if serializer_tasks.size > 0 && num_normal > 0
      if num_normal > 1
        messages += "In addition, #{num_normal} leftover tasks were started separately (without a Serializer).\n"
      else
        messages += "In addition, 1 leftover task was started separately (without a Serializer).\n"
      end
    end

    [ messages, parallelizer_tasks, normal_tasks ]
  end

end

