
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

class CbrainTask::Parallelizer < ClusterTask #:nodoc:

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  after_status_transition '*', 'Failed Setup Prerequisites', :trigger_cascade_prepreq_failures

  def setup #:nodoc:
    return true
  end

  def job_walltime_estimate #:nodoc:
    max = 1.minute
    self.enabled_subtasks.each do |otask|
      wt = otask.job_walltime_estimate || 1.minute
      max = wt if wt > max
    end
    walltime = max + (0.1 * max)
    return walltime
  end

  def cluster_commands #:nodoc:
    subtasks   = self.enabled_subtasks

    commands = [
      "#",
      "# Parallel execution of #{subtasks.size} tasks.",
      "#",
      "",
      "# Initialize the built-in bash seconds counter",
      "SECONDS=0",
      "",
      "# Function to report when a child exits.",
      "child_is_done() {",
      "  echo One task finished after $SECONDS seconds.",
      "}",
      "",
    ]

    subtasks.each do |otask|
      odir    = otask.full_cluster_workdir
      oscript = otask.qsub_script_basename
      oout    = otask.qsub_stdout_basename
      oerr    = otask.qsub_stderr_basename
      touchfile = done_touchfile(otask)
      commands += [
        "",
        "# Run task #{otask.fullname.bash_escape}",
        "",
        "if test -d #{odir.to_s.bash_escape} ; then",
        "  echo Starting script for task '#{otask.fullname.bash_escape}' in background.",
        "  cd #{odir.to_s.bash_escape}",
        "  (",
        "    /bin/bash #{oscript.bash_escape} > #{oout.bash_escape} 2> #{oerr.bash_escape}",
        "    sleep 5",
        "    touch #{touchfile.bash_escape}",
        "  ) &",
        "else",
        "  echo Could not find workdir of task #{otask.fullname.to_s.bash_escape}. Skipping.",
        "fi"
      ]
    end

    commands += [
      "",
      "echo Waiting for all tasks to finish, at `date`",
      "",
      "# Let's trigger the tracking function whenever a subprocess exits.",
      "set -b -m",
      "trap child_is_done SIGCHLD",
      "",
      "# Unfortunately, on some systems the trapped SIGCHLD causes wait",
      "# to return, so we need one wait per subtask!",
      "# If you see any output from 'jobs -r' between the 'finished' messages,",
      "# it means this computer suffers from this bug.",
      ([ 'wait;jobs -r' ] * subtasks.size).join(";"),
      "",
      "trap - SIGCHLD",
      "",
      "echo All tasks completed after $SECONDS seconds, at `date`",
      ""
    ]

    return commands
  end

  def save_results #:nodoc:
    self.addlog("Marking all tasks as ready.")
    self.enabled_subtasks.each do |otask|
      otask.status_transition!("Configured", "Data Ready")
      otask.addlog("#{self.fullname} marking me as \"Data Ready\".")
      otask.remove_prerequisites_for_post_processing(self)
      otask.save!
      otask.meta[:configure_only] = nil # task becomes normal so it can be manipulated by user
    end
    return true
  end

  # Returns true if all enabled subtasks are
  # either Completed or Failed, which is
  # necessary for restarts.
  def all_subtasks_are?(states = /Completed|Failed|Terminated/) #:nodoc:
    return true if self.enabled_subtasks.all? { |otask| otask.status =~ states }
    self.addlog("Cannot proceed, as subtasks are not in states matching #{states.inspect}.")
    return false
  end



  # =========================================================
  # Error Recovery Callbacks
  # =========================================================

  # The only known way for setup to fail is when
  # one of the subtask fails its own settin up,
  # and this causes the parallelizer to enter
  # "Failed Setup Prerequisites". So we just
  # trigger error recovery on the subtasks and
  # try again.
  def recover_from_setup_failure #:nodoc:
    subtasks   = self.enabled_subtasks

    subtasks.each do |otask|
      if otask.recover
        self.addlog("Triggering error recovery for subtask #{otask.tname_tid}")
      end
    end

    return true
  end

  # A failure on cluster can only be caused by a system problem,
  # since the basic parallelizer script is just a simple bash script
  # that runs the bash scripts of other tasks. It happens mostly when
  # the CPU time of the parallelizer has been exceeded. In that case
  # we will try to fix the situation and identify which parallelized
  # tasks are OK and which are not.
  def recover_from_cluster_failure #:nodoc:
    subtasks   = self.enabled_subtasks

    subtasks.each do |otask|
      status    = otask.status
      touchfile = done_touchfile(otask)

      if status == 'Configured'
        if File.exists?(touchfile)
          self.addlog("Subtask #{otask.tname_tid} seems to have finished, marking it as Data Ready.")
          disable_subtask(otask) # we no longer control it
          otask.status_transition!('Configured','Data Ready')
        else
          self.addlog("Subtask #{otask.tname_tid} interrupted, triggering recovery.")
          otask.status_transition!('Configured','Recover Cluster')
        end
        next
      end

      # We'll take this opportunity to stop caring about
      # subtasks that somehow have progressed by themselves.
      if status =~ /Completed|Terminated/
        self.addlog("Subtask #{otask.tname_tid} is #{status}, rescinding control.")
        disable_subtask(otask) # we no longer control it
        next
      end

      # Not sure about this
      if status =~ /Fail/
        self.addlog("Subtask #{otask.tname_tid} failed, triggering recovery.")
        otask.meta[:configure_only] = true
        otask.recover
      end

    end # each subtask

    self.save
    true # we're OK for retyring the parallelizer now
  end



  # =========================================================
  # Restartability Callbacks
  # =========================================================

  def restart_at_setup #:nodoc:
    unless self.all_subtasks_are?(/Completed|Failed|Terminated/)
      self.addlog("This task can only be restarted at Setup if its subtasks are all either Completed, Failed, or Terminated.")
      return false
    end
    self.enabled_subtasks.each do |otask|
      otask.add_prerequisites_for_post_processing(self,'Completed')
      otask.meta[:configure_only] = true
      orig_status = otask.status
      if orig_status =~ /Completed|Terminated/
        otask.restart('Setup')
      else
        otask.status_transition(otask.status, "Failed To Setup") if otask.status =~ /Failed (On Cluster|To PostProcess)/ # resets
        otask.recover
      end
      if orig_status !~ /Prerequisites/ && otask.status !~ /^Recover|Restart/
        self.addlog("Could not recover or restart subtask #{otask.fullname}.")
        return false
      end
      otask.save!
    end
    return true
  end

  def restart_at_cluster #:nodoc:
    self.addlog("This task cannot be restarted at the Cluster stage.")
    self.addlog("It can be restarted at Setup if subtasks are all either Completed, Failed or Terminated.")
    self.addlog("It can be restarted at Post Processing if all subtasks are Completed.")
    return false
  end

  def restart_at_post_processing #:nodoc:
    unless self.all_subtasks_are?(/Completed/)
      self.addlog("This task can only be restarted at Post Processing if its subtasks are all Completed.")
      return false
    end
    self.enabled_subtasks.each do |otask|
      otask.remove_prerequisites_for_post_processing(self)
      otask.meta[:configure_only] = nil
      otask.restart("PostProcess")
      otask.save!
    end
    self.addlog("This parallelizer doesn't need to restart its own post processing.")
    self.addlog("Its subtasks, however, were properly notified to do so.")
    return false
  end

  # If a parallelizer fails its setup prerequisites, then we need
  # to mark its subtasks that are New or Configured the same way.
  def trigger_cascade_prepreq_failures(from_state) #:nodoc
    self.enabled_subtasks.where(:status => [ 'New', 'Configured' ] ).each do |otask|
      otask.addlog("#{self.fullname} indicates setup prereq failure.")
      otask.status_transition(otask.status, 'Failed Setup Prerequisites') rescue true
    end
    return true
  end

  private

  # When a subtask completes, the parallelizer will record
  # that fact in the parallelizer's work directory
  # using a touchfile named ".done-{subtask_run_id}".
  # This method returns the full path of that touchfile.
  def done_touchfile(subtask) #:nodoc
    subtask_touchfile_prefix = Pathname.new(self.full_cluster_workdir) + ".done-"
    s_runid = subtask.run_id
    subtask_touchfile_prefix.to_s + s_runid
  end

end

