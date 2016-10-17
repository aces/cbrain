
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

class CbrainTask::Parallelizer #:nodoc:

  # Returns the list of tasks parallelized;
  # this list includes only the tasks that have been
  # 'enabled' (disabling can be triggered using the
  # interface).
  def enabled_subtasks
    params           = self.params || {}
    task_ids_enabled = params[:task_ids_enabled] || {}
    all_task_ids     = task_ids_enabled.keys.sort { |i1,i2| i1.to_i <=> i2.to_i }
    task_ids         = all_task_ids.collect do |tid|
      if task_ids_enabled[tid].to_s == "1"
        self.add_prerequisites_for_setup(tid, 'Configured')
        tid.to_i
      else
        self.remove_prerequisites_for_setup(tid)
        nil
      end
    end
    task_ids.compact!
    return CbrainTask.where(:id => task_ids)
  end

  # Creates and launch a set of Parallelizers for a set of other
  # CbrainTasks supplied in +tasklist+. All the tasks in +tasklist+
  # are assumed to already have been created with status 'Standby'.
  #
  # Returns an array of three elements:
  #
  # * A message about how things went
  # * An array of the Parallelizer task objects
  # * An array of the leftover task objects not parallelized (if any)
  #
  # Supported options:
  #
  #   :group_size               => group that many task per Parallelizer; default 2
  #   :min_group_size           => if there is a set of leftover tasks smaller than this, they are NOT parallelized; default 2
  #   :initial_rank             => rank counter for task batching
  #   :subtask_level            => level of subtasks in task batch, default 1
  #   :parallelizer_level       => level of Parallelizers in task batch, default 0
  #   :subtask_start_state      => subtask status once parallelized, default 'New'
  #   :parallelizer_start_state => Parallelizer status once created, default 'New'
  #
  # If a block is given, the block will be called once for each
  # Parallelizer with, in its two arguments, the Parallelizer and
  # an array of its subtasks.
  def self.create_from_task_list(tasklist = [], options = {}) #:nodoc:

    return [ "", [], [] ] if tasklist.empty?

    options = { :group_size => options } if options.is_a?(Fixnum) # old API

    unless tasklist.all? { |t| t.status == 'Standby' }
      cb_error "Trying to parallelize a list of tasks that are NOT in Standby state?!?"
    end
    unless tasklist.all? { |t| t.bourreau_id == tasklist[0].bourreau_id }
      cb_error "Trying to parallelize a list of tasks that are NOT all on the same Bourreau?!?"
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
        :group_id        => Group.everyone.id,
        :ncpus           => 512,
        :env_array       => [],
        :script_prologue => "",
        :description =>
          "Standard CBRAIN Parallelizer\n" +
          "\n" +
          "Automatically created by #{self} rev. #{self.revision_info.short_commit}.\n" +
          "Note that the suggested number of CPUs defined here is not in fact used.\n" +
          "Instead, the parallelism factor is determined by the parallelized program's\n" +
          "own configuration.\n"
      )
    end

    # Destructively go through the task list and build Parallelizers
    desttasklist        = tasklist.dup # we'll destroy THIS array, and leave the original intact
    parallelizer_tasks  = [] # parallelizer tasks
    normal_tasks        = [] # tasks launched normally, independently
    num_parallel        = 0 # tasks under parallelizer control

    # Get options
    group_size          = options[:group_size]               || 2
    min_group_size      = options[:min_group_size]           || 2
    min_group_size      = group_size if min_group_size > group_size
    rank                = options[:initial_rank]             || 0 # global counter for all tasks in the batch
    level_task          = options[:subtask_level]            || 1
    level_paral         = options[:parallelizer_level]       || 0
    subtask_start_state = options[:subtask_start_state]      || 'New'
    paral_start_state   = options[:parallelizer_start_state] || 'New'

    while desttasklist.size > 0

      subtasklist  = desttasklist[0,group_size]           # first group_size tasks
      desttasklist = desttasklist[group_size,99999] || [] # destructively, here's the rest

      # For groups too small, we just launch normally
      if subtasklist.size < min_group_size
        subtasklist.each do |task|
          task.status = subtask_start_state
          task.rank   = rank       unless task.rank; rank += 1
          task.level  = level_task unless task.level
          task.save!
          normal_tasks << task
        end
        next # may end the destructive loop, or continue it if we were grouping them all one by one
      end

      # Create the Parallelizer
      first = subtasklist[0]
      description = "Parallelizer ##{parallelizer_tasks.size+1} for #{first.name} x #{subtasklist.size}"
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
        :status         => paral_start_state,
        :params         => { :task_ids_enabled => tasks_ids_enabled },
        :batch_id       => first.batch_id,
        :rank           => rank,
        :level          => level_paral,
        :tool_config_id => tc.id
      )
      rank += 1

      # Add prereqs: the Parallelizer can only start once the
      # subtasks are configured
      subtasklist.each do |task|
        parallelizer.add_prerequisites_for_setup(task, 'Configured')
      end

      # Launch the Parallelizer
      parallelizer.save!
      parallelizer_tasks << parallelizer
      num_parallel       += subtasklist.size

      # Launch the subtasks with prerequisites and the 'Configure Only' meta option
      subtasklist.each do |task|
        task.add_prerequisites_for_post_processing(parallelizer, 'Completed')
        task.status = subtask_start_state # trigger them to start
        task.rank   = rank       unless task.rank; rank += 1
        task.level  = level_task unless task.level
        task.meta[:configure_only]=true
        task.save!
      end

      # Call the user block, if needed
      yield(parallelizer, subtasklist) if block_given?
    end

    messages = ""

    if parallelizer_tasks.size > 1
      messages += "Launched #{parallelizer_tasks.size} Parallelizer tasks (covering a total of #{num_parallel} tasks).\n"
    elsif parallelizer_tasks.size == 1
      messages += "Launched a Parallelizer task (covering a total of #{num_parallel} tasks).\n"
    end

    if parallelizer_tasks.size > 0 && normal_tasks.size > 0
      if normal_tasks.size > 1
        messages += "In addition, #{normal_tasks.size} leftover tasks were started separately (without a Parallelizer).\n"
      else
        messages += "In addition, 1 leftover task was started separately (without a Parallelizer).\n"
      end
    end

    return [ messages, parallelizer_tasks, normal_tasks ]
  end

end

