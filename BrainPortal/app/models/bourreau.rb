
#
# CBRAIN Project
#
# Original author: Pierre Rioux
#
# $Id$
#


#This model represents a remote execution server.
class Bourreau < RemoteResource

  Revision_info="$Id$"
  
  has_many :user_preferences,  :dependent => :nullify
  has_many :cbrain_tasks
  has_many :tool_configs, :dependent => :destroy
  has_and_belongs_to_many :tools

  attr_accessor :operation_messages # no need to store in DB
  
  # Returns the single ToolConfig object that describes the configuration
  # for this Bourreau for all CbrainTasks, or nil if it doesn't exist.
  def global_tool_config
    @global_tool_config_cache ||= ToolConfig.find(:first, :conditions =>
      { :tool_id => nil, :bourreau_id => self.id } )
  end

  # Start a Bourreau remotely. As a requirement for this to work,
  # we need the following attributes set in the Bourreau
  # object:
  #
  # *ssh_control_user*:: Mandatory
  # *ssh_control_host*:: Mandatory
  # *ssh_control_port*:: Optional, default 22
  # *ssh_control_rails_dir*:: Mandatory
  #
  # If DB and/or ActiveResource tunneling is enabled, the
  # remote Bourreau will be told to use the tunnels. This
  # implies that the remote database.yml will be rewritten
  # and the "-p port" option will be set to the value
  # of *tunnel_actres_port* instead of *actres_port*
  def start
    self.operation_messages = "Not configured for remote control."

    return false unless self.has_remote_control_info?
    return false unless RemoteResource.current_resource.is_a?(BrainPortal)

    unless self.start_tunnels
      self.operation_messages = "Could not start the SSH master connection."
      return false
    end

    # What environment will it run under?
    myrailsenv = ENV["RAILS_ENV"] || "production"

    # If we tunnel the DB, we get a non-blank yml file here
    db_yml  = self.has_db_tunneling_info?   ?   self.build_db_yml_for_tunnel(myrailsenv) : ""

    # What port the Rails Bourreau will listen to?
    port = self.has_actres_tunneling_info?  ?   self.tunnel_actres_port : self.actres_port

    # File to capture command output.
    captfile = "/tmp/start.out.#{Process.pid}"
  
    # SSH command to start it up; we pipe to it either a new database.yml file
    # which will be installed, or "" which means to use whatever
    # yml file is already configured at the other end.
    start_command = "ruby #{self.ssh_control_rails_dir}/script/cbrain_remote_ctl " +
                    "start -e #{myrailsenv} -p #{port}"
    self.write_to_remote_shell_command(start_command, :stdout=>captfile) {|io| io.write(db_yml)}

    out = File.read(captfile) rescue ""
    File.unlink(captfile) rescue true
    return true if out =~ /Bourreau Started/i # output of 'cbrain_remote_ctl'
    self.operation_messages = "Remote control command failed\n" +
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

    stop_command = "ruby #{self.ssh_control_rails_dir}/script/cbrain_remote_ctl stop"
    confirm=""
    self.read_from_remote_shell_command(stop_command) {|io| confirm = io.read}   
    self.stop_tunnels
 
    return true if confirm =~ /Bourreau Stopped/i # output of 'cbrain_remote_ctl' 
    return false
  end

  # This method adds Bourreau-specific information fields
  # to the RemoteResourceInfo object normally returned 
  # by the RemoteResource class method of the same name.
  def self.remote_resource_info
    info = super

    queue_tasks_tot_max = Scir::Session.session_cache.queue_tasks_tot_max
    queue_tasks_tot     = queue_tasks_tot_max[0]
    queue_tasks_max     = queue_tasks_tot_max[1]

    worker_pool  = WorkerPool.find_pool(BourreauWorker)
    workers      = worker_pool.workers
    workers_pids = workers.map(&:pid).join(",")

    worker_revinfo    = BourreauWorker.revision_info
    worker_lc_rev     = worker_revinfo.svn_id_rev
    worker_lc_author  = worker_revinfo.svn_id_author
    worker_lc_date    = worker_revinfo.svn_id_datetime

    info.merge!(
      # Bourreau info
      :bourreau_cms       => CBRAIN::CLUSTER_TYPE,
      :bourreau_cms_rev   => Scir::Session.session_cache.revision_info,
      :tasks_max          => queue_tasks_max,
      :tasks_tot          => queue_tasks_tot,

      :worker_pids        => workers_pids,
      :worker_lc_rev      => worker_lc_rev,
      :worker_lc_author   => worker_lc_author,
      :worker_lc_date     => worker_lc_date
    )

    return info
  end

  protected

  def build_db_yml_for_tunnel(railsenv) #:nodoc:
    myconfig = self.class.current_resource_db_config(railsenv) # a copy of the active config

    myconfig["host"]   = "127.0.0.1"
    myconfig["port"]   = self.tunnel_mysql_port
    myconfig.delete("socket")

    yml = "\n" +
          "#\n" +
          "# File created automatically on Portal Side\n" +
          "# by " + self.revision_info.svn_id_pretty_file_rev_author_date + "\n" +
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
  def send_command_get_task_outputs(task_id,run_number=nil)
    command = RemoteCommand.new(
      :command     => 'get_task_outputs',
      :task_ids    => task_id.to_s,
      :run_number  => run_number
    )
    send_command(command) # will return a command object with stdout and stderr
  end

  # Utility method to send a +alter_tasks+ command to a
  # Bourreau RemoteResource, whether local or not.
  # +tasks+ must be a single task ID or an array of such,
  # or a single CbrainTask object or an array of such.
  # +new_task_status+ is one of the keywords recognized by
  # process_command_alter_tasks(); in the case where operation
  # is 'Duplicate', then a +new_bourreau_id+ can be supplied too.
  def send_command_alter_tasks(tasks,new_task_status,new_bourreau_id=nil)
    tasks    = [ tasks ] unless tasks.is_a?(Array)
    task_ids = tasks.map { |t| t.is_a?(CbrainTask) ? t.id : t.to_i }
    command  = RemoteCommand.new(
      :command         => 'alter_tasks',
      :task_ids        => task_ids.join(","),
      :new_task_status => new_task_status,
      :new_bourreau_id => new_bourreau_id
    )
    send_command(command)
  end



  ############################################################################
  # Commands Implemented by Bourreaux
  ############################################################################

  protected

  # Starts Bourreau worker processes.
  # This also triggers a 'wakeup' command if they are already
  # started.
  def self.process_command_start_workers(command)
    myself = RemoteResource.current_resource
    cb_error "Got worker control command #{command.command} but I'm not a Bourreau!" unless
      myself.is_a?(Bourreau)

    # Returns a logger object or the symbol :auto
    logger = self.initialize_worker_logger()

    # Workers are started when created
    worker_pool = WorkerPool.create_or_find_pool(BourreauWorker,
       CBRAIN::BOURREAU_WORKERS_INSTANCES,
       { :check_interval => CBRAIN::BOURREAU_WORKERS_CHECK_INTERVAL,
         :worker_log     => logger, # nil, a logger object, or :auto
         :log_level      => CBRAIN::BOURREAU_WORKERS_VERBOSE ? Log4r::DEBUG : Log4r::INFO # for :auto
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
    taskids   = command.task_ids.split(/,/)
    newstatus = command.new_task_status

    tasks_affected = 0

    taskids.each do |task_id|
      begin
        task       = CbrainTask.find(task_id.to_i)
        old_status = task.status # so we can detect if the operation did anything.

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

        # 'Destroy' is different, it terminates (if allowed) then
        # removes all traces of the task from the DB.
        if newstatus == "Destroy"  # verb instead of adjective
          task.destroy
          next
        end

        # These actions trigger special handling code in the workers
        task.recover                       if newstatus == "Recover"        # For 'Failed*' tasks
        task.restart(Regexp.last_match[1]) if newstatus =~ /^Restart (\S+)/ # For 'Completed' tasks only

        # The 'Duplicate' operation copies the task object into a brand new task.
        # As a side effect, the task can be reassigned to another Bourreau too
        # (Note that the task will fail at Setup if the :share_wd_id attribute specify
        # a task that is now on the original Bourreau).
        # Duplicating a task could also be performed on the client side (BrainPortal).
        if (newstatus == 'Duplicate')
          new_bourreau_id = command.new_bourreau_id || task.bourreau_id || myself.id
          new_task = task.class.new(task.attributes) # a kind of DUP!
          new_task.bourreau_id     = new_bourreau_id
          new_task.cluster_jobid   = nil
          new_task.cluster_workdir = nil
          new_task.run_number      = 1
          new_task.status          = "New"
          new_task.addlog_context(self,"Duplicated from task '#{task.bname_tid}'.")
          task=new_task
        end

        # OK now, if something has changed (based on status), we proceed we the update.
        next unless task.status != old_status
        task.addlog_current_resource_revision
        task.save
        tasks_affected += 1 if task.bourreau_id == myself.id
      rescue
        puts "Something has gone wrong altering task '#{task_id}' with new status '#{newstatus}'."
      end
    end

    # Artifically trigger a 'wakeup workers' commmand if any task was
    # affected locally. Unfortunately we can't wake up workers on
    # a different Bourreaux yet.
    if tasks_affected > 0
      myself.send_command_start_workers
    end

  end

  # Returns the STDOUT and STDERR of a task.
  def self.process_command_get_task_outputs(command)
    task_id    = command.task_ids.to_i # expects only one
    task = CbrainTask.find(task_id)
    run_number = command.run_number || task.run_number
    task.capture_job_out_err(run_number)
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
  def self.initialize_worker_logger

    log_to = CBRAIN::BOURREAU_WORKERS_LOG_TO

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
        blogger.level = CBRAIN::BOURREAU_WORKERS_VERBOSE ? Log4r::DEBUG : Log4r::INFO
      end

    # Option 3: combined log a file
    elsif log_to == 'combined'
      blogger = Log4r::Logger['BourreauWorker']
      unless blogger
        blogger = Log4r::Logger.new('BourreauWorker')
        blogger.add(Log4r::RollingFileOutputter.new('bourreau_workers_outputter',
                      :filename  => "#{RAILS_ROOT}/log/BourreauWorkers.combined..log",
                      :formatter => Log4r::PatternFormatter.new(:pattern => "%d %l %m"),
                      :maxsize   => 1000000, :trunc => 600000))
        blogger.level = CBRAIN::BOURREAU_WORKERS_VERBOSE ? Log4r::DEBUG : Log4r::INFO
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
