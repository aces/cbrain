
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

# This model represents a remote execution server.
class Bourreau < RemoteResource

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  has_many :cbrain_tasks, :dependent => :restrict
  has_many :tool_configs, :dependent => :destroy
  has_many :tools, :through => :tool_configs, :uniq => true

  attr_accessor :operation_messages # no need to store in DB

  def self.pretty_type #:nodoc:
    "Execution"
  end

  # Returns the single ToolConfig object that describes the configuration
  # for this Bourreau for all CbrainTasks, or nil if it doesn't exist.
  def global_tool_config
    @global_tool_config_cache ||= ToolConfig.where( :tool_id => nil, :bourreau_id => self.id ).first
  end

  # Returns the Scir subclass
  # responsible for communicating with the cluster;
  # this method is only meaningful when the current Rails
  # app is a Bourreau itself.
  def scir_class
    return @scir_class if @scir_class
    cms_class = self.cms_class || "Unset"
    if cms_class !~ /\AScir\w+\z/ # old keyword convention?!?
      cb_error "Value of cms_class in Bourreau record invalid: '#{cms_class}'"
    end
    @scir_class = Class.const_get(cms_class)
    @scir_class
  end

  # Returns the Scir session subclass object
  # responsible for communicating with the cluster;
  # this method is only meaningful when the current Rails
  # app is a Bourreau itself.
  def scir_session
    return @scir_session_cache if @scir_session_cache
    @scir_session_cache = Scir.session_builder(self.scir_class) # e.g. ScirUnix::Session.new()
    @scir_session_cache
  end



  ############################################################################
  # Remote Control Methods
  ############################################################################

  # Start a Bourreau remotely. As a requirement for this to work,
  # we need the following attributes set in the Bourreau
  # object:
  #
  # *ssh_control_user*:: Mandatory
  # *ssh_control_host*:: Mandatory
  # *ssh_control_port*:: Optional, default 22
  # *ssh_control_rails_dir*:: Mandatory
  #
  # If DB and/or ActiveResource tunnelling is enabled, the
  # remote Bourreau will be told to use the tunnels. This
  # implies that the remote database.yml will be rewritten
  # and the "-p port" option will be set to the value
  # of *tunnel_actres_port* instead of *actres_port*
  def start
    self.operation_messages = "Unknown internal error."

    self.online = true

    self.zap_info_cache(:info)
    self.zap_info_cache(:ping)

    unless self.has_remote_control_info?
      self.operation_messages = "Not configured for remote control."
      return false
    end

    unless RemoteResource.current_resource.is_a?(BrainPortal)
      self.operation_messages = "Only a Portal can start a Bourreau."
      return false
    end

    unless self.start_tunnels
      self.operation_messages = "Could not start the SSH master connection."
      return false
    end

    # What environment will it run under?
    myrailsenv = Rails.env || "production"

    # If we tunnel the DB, we get a non-blank yml file here
    db_yml  = self.has_db_tunnelling_info?   ?   self.build_db_yml_for_tunnel(myrailsenv) : ""

    # What port the Rails Bourreau will listen to?
    port = self.has_actres_tunnelling_info?  ?   self.tunnel_actres_port : self.actres_port # actres_port no longer supported

    # File to capture command output.
    captfile = "/tmp/start.out.#{Process.pid}"

    # If the remote host is actually just a frontend before the REAL
    # host, add the "-R host -H http_port -D db_port" special options to the command
    proxy_args = ""
    if ! self.proxied_host.blank?
      proxy_args = "-R #{self.proxied_host.bash_escape} -H #{port.to_s.bash_escape} -D #{self.tunnel_mysql_port.to_s.bash_escape}"
    end

    # SSH command to start it up; we pipe to it either a new database.yml file
    # which will be installed, or "" which means to use whatever
    # yml file is already configured at the other end.
    start_command = "cd #{self.ssh_control_rails_dir.to_s.bash_escape}; bundle exec ruby #{self.ssh_control_rails_dir.to_s.bash_escape}/script/cbrain_remote_ctl #{proxy_args} start -e #{myrailsenv.to_s.bash_escape} -p #{port.to_s.bash_escape} 2>&1"
    self.write_to_remote_shell_command(start_command, :stdout => captfile) { |io| io.write(db_yml) }

    out = File.read(captfile) rescue ""
    File.unlink(captfile) rescue true
    if out =~ /Bourreau Started/i # output of 'cbrain_remote_ctl'
      self.operation_messages = "Execution Server #{self.name} started.\n" +
                                "Command: #{start_command}\n" +
                                "Output:\n---Start Of Output---\n#{out}\n---End Of Output---\n"
      self.save
      return true
    end
    self.operation_messages = "Remote control command for #{self.name} failed.\n" +
                              "Command: #{start_command}\n" +
                              "Output:\n---Start Of Output---\n#{out}\n---End Of Output---\n"
    return false
  end

  # Stop a Bourreau remotely. The requirements for this to work are
  # the same as with start().
  def stop
    return false unless self.has_remote_control_info?
    return false unless RemoteResource.current_resource.is_a?(BrainPortal)
    return false unless self.start_tunnels  # tunnels must be STARTed in order to STOP the Bourreau!

    self.zap_info_cache(:info)
    self.zap_info_cache(:ping)

    # If the remote host is actually just a frontend before the REAL
    # host, add the "-R host -H http_port -D db_port" special options to the command
    proxy_args = ""
    if ! self.proxied_host.blank?
      port = self.has_actres_tunnelling_info?  ? self.tunnel_actres_port : self.actres_port # actres_port no longer supported
      proxy_args = "-R #{self.proxied_host.to_s.bash_escape} -H #{port.to_s.bash_escape} -D #{self.tunnel_mysql_port.to_s.bash_escape}"
    end

    stop_command = "cd #{self.ssh_control_rails_dir.to_s.bash_escape}; bundle exec ruby #{self.ssh_control_rails_dir.to_s.bash_escape}/script/cbrain_remote_ctl #{proxy_args} stop"
    confirm = self.read_from_remote_shell_command(stop_command) {|io| io.read}

    return true if confirm =~ /Bourreau Stopped/i # output of 'cbrain_remote_ctl'
    return false
  end

  # Starts a Rails console on a remote Bourreau. The remote console's STDIN,
  # STDOUT and STDERR channel will be connected to the current TTY. Obviously,
  # this method is meant to be invoked while already on a portal side rails
  # console, for debugging or inspecting a remote installation.
  def start_remote_console
    raise "This method can only be invoked in an interactive setting." unless STDIN.tty? && STDOUT.tty? && STDERR.tty?

    unless self.has_remote_control_info?
      self.operation_messages = "Not configured for remote control."
      return false
    end

    unless RemoteResource.current_resource.is_a?(BrainPortal)
      self.operation_messages = "Only a Portal can start a Bourreau."
      return false
    end

    unless self.start_tunnels
      self.operation_messages = "Could not start the SSH master connection."
      return false
    end

    # What environment will it run under?
    myrailsenv = Rails.env || "production"

    # If we tunnel the DB, we get a non-blank yml file here
    db_yml  = self.has_db_tunnelling_info?   ?   self.build_db_yml_for_tunnel(myrailsenv) : ""

    # If the remote host is actually just a frontend before the REAL
    # host, add the "-R host -H http_port -D db_port" special options to the command
    proxy_args = ""
    if ! self.proxied_host.blank?
      port = self.has_actres_tunnelling_info?  ? self.tunnel_actres_port : self.actres_port # actres_port no longer supported
      proxy_args = "-R #{self.proxied_host.to_s.bash_escape} -H #{port.to_s.bash_escape} -D #{self.tunnel_mysql_port.to_s.bash_escape}"
    end

    # Copy the database.yml file
    # Note: the database.yml file will be removed automatically by the cbrain_remote_ctl script when it exits.
    copy_command = "cat > #{self.ssh_control_rails_dir.to_s.bash_escape}/config/database.yml"
    self.write_to_remote_shell_command(copy_command) { |io| io.write(db_yml) }

    # SSH command to start the console.
    start_command = "cd #{self.ssh_control_rails_dir.to_s.bash_escape}; bundle exec ruby #{self.ssh_control_rails_dir.to_s.bash_escape}/script/cbrain_remote_ctl #{proxy_args} console -e #{myrailsenv.to_s.bash_escape}"
    self.read_from_remote_shell_command(start_command, :force_pseudo_ttys => true) # no block, so that ttys gets connected to remote stdin, stdout and stderr
  end

  # This method adds Bourreau-specific information fields
  # to the RemoteResourceInfo object normally returned
  # by the RemoteResource class method of the same name.
  def self.remote_resource_info
    info = super
    myself = RemoteResource.current_resource

    queue_tasks_tot_max = myself.scir_session.queue_tasks_tot_max rescue [ "unknown", "unknown" ]
    queue_tasks_tot     = queue_tasks_tot_max[0]
    queue_tasks_max     = queue_tasks_tot_max[1]

    worker_pool  = WorkerPool.find_pool(BourreauWorker)
    workers      = worker_pool.workers
    worker_pids  = workers.map(&:pid).join(",")

    worker_revinfo    = BourreauWorker.revision_info.self_update
    worker_lc_rev     = worker_revinfo.short_commit
    worker_lc_author  = worker_revinfo.author
    worker_lc_date    = worker_revinfo.datetime

    num_sync_userfiles  = myself.sync_status.count         # number of files locally synchronized
    size_sync_userfiles = myself.sync_status.joins(:userfile).sum("userfiles.size") # tot sizes of these files
    num_tasks           = myself.cbrain_tasks.count        # total number of tasks on this Bourreau
    num_active_tasks    = myself.cbrain_tasks.active.count # number of active tasks on this Bourreau

    info.merge!(
      # Bourreau info
      :bourreau_cms              => myself.cms_class || "Unconfigured",
      :bourreau_cms_rev          => (myself.scir_session.revision_info.to_s rescue Object.revision_info.to_s),
      :tasks_max                 => queue_tasks_max,
      :tasks_tot                 => queue_tasks_tot,

      # Worker info
      :worker_pids               => worker_pids,
      :worker_lc_rev             => worker_lc_rev,
      :worker_lc_author          => worker_lc_author,
      :worker_lc_date            => worker_lc_date,

      # Stats
      :num_sync_cbrain_userfiles  => num_sync_userfiles,
      :size_sync_cbrain_userfiles => size_sync_userfiles,
      :num_cbrain_tasks           => num_tasks,
      :num_active_cbrain_tasks    => num_active_tasks,
    )

    return info
  end

  # Returns a lighter and faster-to-generate 'ping' information
  # for this server; the object returned is RemoteResourceInfo
  # with the same quick fields returned by
  # RemoteResource.ping_remote_resource_info, plus the PIDs
  # of the Bourreau's workers.
  def self.remote_resource_ping
    myself             = RemoteResource.current_resource

    # Worker info
    worker_pool        = WorkerPool.find_pool(BourreauWorker) rescue nil
    workers            = worker_pool.workers rescue nil
    worker_pids        = workers.map(&:pid).join(",") rescue '???'

    # Stats
    num_sync_userfiles  = myself.sync_status.count         # number of files locally synchronized
    size_sync_userfiles = myself.sync_status.joins(:userfile).sum("userfiles.size") # tot sizes of these files
    num_tasks           = myself.cbrain_tasks.count        # total number of tasks on this Bourreau
    num_active_tasks    = myself.cbrain_tasks.active.count # number of active tasks on this Bourreau

    info = super
    info[:worker_pids]                = worker_pids
    info[:num_sync_cbrain_userfiles]  = num_sync_userfiles
    info[:size_sync_cbrain_userfiles] = size_sync_userfiles
    info[:num_cbrain_tasks]           = num_tasks
    info[:num_active_cbrain_tasks]    = num_active_tasks
    info
  end

  protected # internal methods for remote control operations above

  def build_db_yml_for_tunnel(railsenv) #:nodoc:
    myconfig = self.class.current_resource_db_config(railsenv) # a copy of the active config

    myconfig["host"]   = "127.0.0.1"
    myconfig["port"]   = self.tunnel_mysql_port
    myconfig.delete("socket")

    yml = "\n" +
          "#\n" +
          "# File created automatically on Portal Side\n" +
          "# by " + self.revision_info.format("%f %s %a %d") + "\n" +
          "#\n" +
          "\n" +
          "#{railsenv}:\n"
    myconfig.each do |field,val|
       yml += "  #{field}: #{val.to_s}\n"
    end
    yml += "\n"

    yml
  end



  ############################################################################
  # Utility Shortcuts To Send Commands
  ############################################################################

  public

  # Utility method to send a +get_task_outputs+ command to a
  # Bourreau RemoteResource, whether local or not.
  def send_command_get_task_outputs(task_id,run_number=nil,stdout_lim=nil,stderr_lim=nil)
    command = RemoteCommand.new(
      :command     => 'get_task_outputs',
      :task_ids    => task_id.to_s,
      :run_number  => run_number,
      :stdout_lim  => stdout_lim,
      :stderr_lim  => stderr_lim,
    )
    send_command(command) # will return a command object with stdout and stderr
  end

  # Utility method to send a +alter_tasks+ command to a
  # Bourreau RemoteResource, whether local or not.
  # +tasks+ must be a single task ID or an array of such,
  # or a single CbrainTask object or an array of such.
  # +new_task_status+ is one of the keywords recognized by
  # process_command_alter_tasks(); in the case where operation
  # is 'Duplicated', then a +new_bourreau_id+ can be supplied too.
  def send_command_alter_tasks(tasks,new_task_status,new_bourreau_id=nil,archive_dp_id=nil)
    tasks    = [ tasks ] unless tasks.is_a?(Array)
    task_ids = tasks.map { |t| t.is_a?(CbrainTask) ? t.id : t.to_i }
    command  = RemoteCommand.new(
      :command                  => 'alter_tasks',
      :task_ids                 => task_ids.join(","),
      :new_task_status          => new_task_status,
      :new_bourreau_id          => new_bourreau_id,
      :archive_data_provider_id => archive_dp_id
    )
    send_command(command)
  end



  ############################################################################
  # Control Commands Implemented by Bourreaux
  ############################################################################

  protected

  # Starts Bourreau worker processes.
  # This also triggers a 'wakeup' command if they are already
  # started.
  def self.process_command_start_workers(command)
    myself = RemoteResource.current_resource
    cb_error "Got worker control command #{command.command} but I'm not a Bourreau!" unless
      myself.is_a?(Bourreau)

    num_instances = myself.workers_instances
    chk_time      = myself.workers_chk_time
    log_to        = myself.workers_log_to
    verbose       = myself.workers_verbose   || 0

    cb_error "Cannot start workers: improper number of instances to start in config (must be 0..20)." unless
       num_instances && num_instances >= 0 && num_instances < 21
    cb_error "Cannot start workers: improper check interval in config (must be 5..3600)." unless
       chk_time && chk_time >= 5 && chk_time <= 3600
    cb_error "Cannot start workers: improper log destination keyword in config (must be none, separate, stdout|stderr, combined, or bourreau)." unless
       (! log_to.blank? ) && log_to =~ /\A(none|separate|combined|bourreau|stdout|stderr|stdout\|stderr|stderr\|stdout)\z/

    # Returns a logger object or the symbol :auto
    logger = self.initialize_worker_logger(log_to,verbose)

    # Workers are started when created
    worker_pool = WorkerPool.create_or_find_pool(BourreauWorker,
       num_instances,
       { :name           => "BourreauWorker #{myself.name}",
         :check_interval => chk_time,
         :worker_log     => logger, # nil, a logger object, or :auto
         :log_level      => verbose > 1 ? Log4r::DEBUG : Log4r::INFO # for :auto
       }
    )
    worker_pool.wake_up_workers
  end

  # Stops Bourreau worker processes.
  def self.process_command_stop_workers(command)
    myself = RemoteResource.current_resource
    cb_error "Got worker control command #{command.command} but I'm not a Bourreau!" unless
      myself.is_a?(Bourreau)
    worker_pool = WorkerPool.find_pool(BourreauWorker)
    worker_pool.stop_workers
  end

  # Wakes up Bourreau worker processes.
  def self.process_command_wakeup_workers(command)
    myself = RemoteResource.current_resource
    cb_error "Got worker control command #{command.command} but I'm not a Bourreau!" unless
      myself.is_a?(Bourreau)
    worker_pool = WorkerPool.find_pool(BourreauWorker)
    worker_pool.wake_up_workers
  end

  # Modifies a task's state.
  def self.process_command_alter_tasks(command)
    myself = RemoteResource.current_resource
    cb_error "Got control command #{command.command} but I'm not a Bourreau!" unless
      myself.is_a?(Bourreau)

    # 'taskids' is an array of tasks to process.
    # 'newstatus', as received in the command object, is not
    # necessarily an official legal task status name, it can be a
    # description of an action to perform here (e.g. RemoveWorkDir)
    taskids   = command.task_ids.split(/,/)
    newstatus = command.new_task_status

    tasks_affected = 0

    CBRAIN.spawn_with_active_records(:admin, "AlterTask #{newstatus}") do

    taskids.shuffle.each_with_index do |task_id,count|
      $0 = "AlterTask #{newstatus} ID=#{task_id} #{count+1}/#{taskids.size}\0"
      task = CbrainTask.where(:id => task_id, :bourreau_id => myself.id).first
      next unless task # doesn't even exist? just ignore it

      begin
        old_status = task.status # so we can detect if the operation did anything.
        task.update_status

        # 'Destroy' is different, it terminates (if allowed) then
        # removes all traces of the task from the DB.
        if newstatus == "Destroy"  # verb instead of adjective
          task.destroy
          next
        end

        # The 'Duplicated' operation copies the task object into a brand new task.
        # As a side effect, the task can be reassigned to another Bourreau too
        # (Note that the task will fail at Setup if the :share_wd_id attribute specify
        # a task that currently is on the original Bourreau).
        # Duplicating a task could also be performed on the client side (BrainPortal).
        if newstatus == 'Duplicated'
          new_bourreau_id = command.new_bourreau_id || task.bourreau_id || myself.id
          new_task = task.class.new(task.attributes) # a kind of DUP!
          new_task.bourreau_id                 = new_bourreau_id
          new_task.cluster_jobid               = nil
          new_task.cluster_workdir             = nil
          new_task.cluster_workdir_size        = nil
          new_task.workdir_archived            = false
          new_task.workdir_archive_userfile_id = nil
          new_task.run_number                  = 0
          new_task.status                      = "Duplicated"
          new_task.addlog_context(self,"Duplicated from task '#{task.bname_tid}'.")
          task=new_task
        end

        # Handle archiving or unarchiving the task's workdir
        if newstatus == 'ArchiveWorkdir'
          task.archive_work_directory
          next
        elsif newstatus == 'ArchiveWorkdirAsFile'
          task.archive_work_directory_to_userfile(command.archive_data_provider_id)
          next
        elsif newstatus == 'UnarchiveWorkdir'
          if task.archived_status == :userfile # automatically guess which kind of unarchiving to do
            task.unarchive_work_directory_from_userfile
          else
            task.unarchive_work_directory
          end
          next
        elsif newstatus == 'RemoveWorkdir'
          task.send(:remove_cluster_workdir) # it's a protected method
          next
        end

        # No other operations are allowed for archived tasks,
        # no matter what their status is.
        next if task.workdir_archived?

        # The method we'll now call are defined in the Bourreau side's CbrainTask model.
        # These methods trigger task control actions on the cluster.
        # They will update the "status" field depending on the action's result;
        # if the action is invalid it will silently be ignored and the task
        # will stay unchanged.
        task.suspend      if newstatus == "Suspended"
        task.resume       if newstatus == "On CPU"
        task.hold         if newstatus == "On Hold"
        task.release      if newstatus == "Queued"
        task.terminate    if newstatus == "Terminated"

        # These actions trigger special handling code in the workers
        task.recover                       if newstatus == "Recover"         # For 'Failed*' tasks
        task.restart(Regexp.last_match[1]) if newstatus =~ /\ARestart (\S+)/ # For 'Completed' or 'Terminated' tasks only

        # OK now, if something has changed (based on status), we proceed we the update.
        next if task.status == old_status
        task.addlog_current_resource_revision("New status: #{task.status}")
        task.save
        tasks_affected += 1 if task.bourreau_id == myself.id
      rescue => ex
        Rails.logger.debug "Something has gone wrong altering task '#{task_id}' with new status '#{newstatus}'."
        Rails.logger.debug "#{ex.class.to_s}: #{ex.message}"
        Rails.logger.debug ex.backtrace.join("\n")
      end
    end

    # Artifically trigger a 'wakeup workers' commmand if any task was
    # affected locally. Unfortunately we can't wake up workers on
    # a different Bourreau yet.
    if tasks_affected > 0
      myself.send_command_start_workers
    end

    end # spawn

  end

  # Returns the STDOUT and STDERR of a task.
  def self.process_command_get_task_outputs(command)
    task_id    = command.task_ids.to_i # expects only one
    task = CbrainTask.find(task_id)
    run_number = command.run_number || task.run_number
    stdout_lim = command.stdout_lim
    stderr_lim = command.stderr_lim
    task.capture_job_out_err(run_number,stdout_lim,stderr_lim)
    command.cluster_stdout = task.cluster_stdout
    command.cluster_stderr = task.cluster_stderr
    command.script_text    = task.script_text
  rescue => e
    command.cluster_stdout = "Bourreau Exception: #{e.class} #{e.message}\n"
    command.cluster_stderr = "Bourreau Exception:\n#{e.backtrace.join("\n")}\n"
    command.script_text    = ""
  end

  private

  # Create the logger object for the workers.
  # Returns nil, or a logger object, or the symbol :auto
  def self.initialize_worker_logger(log_to,verbose_level)

    # Option 1: the Worker class itself will set them up, one per worker.
    return :auto if log_to == 'separate'

    blogger = nil # means no logging.

    # Option 2: log to stdout or stderr
    if log_to =~ /stdout|stderr/i
      blogger = Log4r::Logger['BourreauWorker']
      unless blogger
        blogger = Log4r::Logger.new('BourreauWorker')
        if log_to =~ /stdout/i
          stdout_op = Log4r::Outputter.stdout
          stdout_op.formatter = Log4r::PatternFormatter.new(:pattern => "%d %l %m")
          blogger.add(stdout_op)
        end
        if log_to =~ /stderr/i
          stderr_op = Log4r::Outputter.stderr
          stderr_op.formatter = Log4r::PatternFormatter.new(:pattern => "%d %l %m")
          blogger.add(stderr_op)
        end
        blogger.level = verbose_level > 1 ? Log4r::DEBUG : Log4r::INFO
      end

    # Option 3: combined log a file
    elsif log_to == 'combined'
      blogger = Log4r::Logger['BourreauWorker']
      unless blogger
        blogger = Log4r::Logger.new('BourreauWorker')
        blogger.add(Log4r::RollingFileOutputter.new('bourreau_workers_outputter',
                      :filename  => "#{Rails.root}/log/BourreauWorkers.combined..log",
                      :formatter => Log4r::PatternFormatter.new(:pattern => "%d %l %m"),
                      :maxsize   => 1000000, :trunc => 600000))
        blogger.level = verbose_level > 1 ? Log4r::DEBUG : Log4r::INFO
      end

    # Option 4: use RAIL's own logger
    elsif log_to == 'bourreau'
      blogger = logger # Rails app logger
    end

    # Return the logger object for the workers
    blogger
  end

  # NOTE: 'private' in effect here.

end
