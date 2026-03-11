
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

  has_many :cbrain_tasks, :dependent => :restrict_with_exception
  has_many :tool_configs, :dependent => :destroy
  has_many :tools, -> { distinct }, :through => :tool_configs

  attr_accessor :operation_messages # no need to store in DB

  api_attr_visible :name, :user_id, :group_id, :online, :read_only, :description

  validates :active_resource_control_port, numericality: { only_integer: true, greater_than: 1024, less_than: 65536 }, allow_blank: true

  validates_format_of :reverse_service_user, :with => /\A\w[\w\-\.]*\z/,
                      :message  => 'is invalid as only the following characters are accepted: alphanumeric characters, _, -, and .',
                      :allow_blank => true
  validates_format_of :reverse_service_host, :with => /\A\w[\w\-\.]*\z/,
                      :message  => 'is invalid as only the following characters are accepted: alphanumeric characters, _, -, and .',
                      :allow_blank => true
  validates           :reverse_service_port, numericality: { only_integer: true, greater_than: 21, less_than: 65536 }, allow_blank: true
  validates_format_of :reverse_service_db_socket_path,:with => /\A(localhost:\d+|[\w\.]+:\d+|\/[\w\-\.\=\+\/]*)\z/,
                      :message  => 'is invalid as only \"localhost:nnnn\" or \"hostname:nnnn\" or a full path with simple characters are accepted: a-z, A-Z, 0-9, _, +, =, . and of course /',
                      :allow_blank => true
  validates_format_of :reverse_service_ssh_agent_socket_path, :with => /\A\/[\w\-\.\=\+\/]*\z/,
                      :message  => 'is invalid as only paths with simple characters are accepted: a-z, A-Z, 0-9, _, +, =, . and of course /',
                      :allow_blank => true

  validate :all_reverse_service_params_supplied

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
  # Utility property checkers
  ############################################################################

  def docker_present? #:nodoc:
    docker_executable_name.present?
  end

  alias docker_present docker_present? #:nodoc:


  def singularity_present? #:nodoc:
    singularity_executable_name.present?
  end

  alias singularity_present singularity_present? #:nodoc:



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
  def start
    self.operation_messages = ""

    self.online = true

    self.zap_info_cache

    # Utility to append to a temporary internal log
    # a bunch of useful messages.
    logit = ->(message, step=nil) do
       self.operation_messages += "=====================================\n"
       self.operation_messages += Time.now.localtime.strftime "[%Y-%m-%d %H:%M:%S %Z]"
       self.operation_messages += " (#{step}) " if step.present?
       self.operation_messages += (message.strip + "\n")
    end

    unless self.has_remote_control_info?
      logit.( "Not configured for remote control: missing user/host." )
      return false
    end

    unless RemoteResource.current_resource.is_a?(BrainPortal)
      logit.( "Only a Portal can start a Bourreau." )
      return false
    end

    unless self.start_tunnels # this will detect and re-use an existing one, if any
      logit.( "Could not start the SSH process.", "Start SSH Master" )
      return false
    end
    logit.( "Main SSH tunnel started successfully", "Start SSH Master" )

    if self.is_alive?(:ping, true)
      logit.( "Bourreau process was found to be already running.", "Check Bourreau Process" )
      return true
    end

    # In the case of the alternate configuration with
    # a reverse service, we first run a program on the
    # remote side called 'cbrain_reverse_ssh' which will
    # try to establish (or rediscover) a separate SSH process
    # with a DB tunnel and a SSH agent tunnel.
    if self.use_reverse_service?
      rev_user    = self.reverse_service_user
      rev_host    = self.reverse_service_host
      rev_port    = self.reverse_service_port
      rev_dbsock  = self.reverse_service_db_socket_path
      rev_sshsock = self.reverse_service_ssh_agent_socket_path
      start_reverse_ssh_command = "cd #{self.ssh_control_rails_dir.to_s.bash_escape}; script/cbrain_reverse_ssh #{rev_user.bash_escape} #{rev_host.bash_escape} #{rev_port.bash_escape} #{rev_dbsock.bash_escape} #{rev_sshsock.bash_escape} #{self.name.bash_escape} 2>&1"
      CBRAIN.with_unlocked_agent # in case the agent was relocked while cbrain_reverse_ssh was setting up
      out = self.read_from_remote_shell_command(start_reverse_ssh_command) { |io| io.read() } rescue "popen exception"
      all_ok = (out =~ /CBRAIN Reverse SSH Started/i) # from output of 'cbrain_reverse_ssh'
      logit.( "Remote SSH process #{all_ok ? 'started' : 'failed to start'}.\n" +
              "Command: #{start_reverse_ssh_command}\n" +
              "---Start Of Output---\n#{out.strip}\n---End Of Output---\n",
              "Start Reverse Service" )
      return false if ! all_ok
    end

    # What environment will it run under?
    myrailsenv = Rails.env || "production"

    # This is a copy of the database.yml file that the portal
    # uses, but with the connection parameters adjusted.
    db_yml = self.build_db_yml_for_tunnel(myrailsenv)

    # File to capture command output.
    captfile = "/tmp/start.out.#{Process.pid}"

    # SSH command to start it up; we pipe to it either a new database.yml file
    # which will be installed, or "" which means to use whatever
    # yml file is already configured at the other end.
    CBRAIN.with_unlocked_agent # in case the agent was relocked while cbrain_reverse_ssh was setting up
    start_command = "cd #{self.ssh_control_rails_dir.to_s.bash_escape}; script/cbrain_remote_ctl start -e #{myrailsenv.to_s.bash_escape} 2>&1"
    self.write_to_remote_shell_command(start_command, :stdout => captfile) { |io| io.write(db_yml) }

    out = File.read(captfile) rescue ""
    File.unlink(captfile) rescue true
    all_ok = (out =~ /Bourreau Started/i) # from output of 'cbrain_remote_ctl'
    logit.( "Execution Server #{self.name} #{all_ok ? 'started' : 'failed'}.\n" +
            "Command: #{start_command}\n" +
            "Output:\n---Start Of Output---\n#{out.strip}\n---End Of Output---\n",
            "Start Bourreau Process" )
    if all_ok
      self.save
      return true
    end
    return false
  #ensure
  #  Rails.logger.debug self.operation_messages if self.operation_messages.present?
  end

  # Stop a Bourreau remotely. The requirements for this to work are
  # the same as with start().
  def stop
    return false unless self.has_remote_control_info?
    return false unless RemoteResource.current_resource.is_a?(BrainPortal)
    return false unless self.start_tunnels  # tunnels must be STARTed in order to STOP the Bourreau!

    self.zap_info_cache

    stop_command = "cd #{self.ssh_control_rails_dir.to_s.bash_escape}; script/cbrain_remote_ctl stop"
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

    # This is a copy of the database.yml file that the portal
    # uses, but with the connection parameters adjusted.
    db_yml = self.build_db_yml_for_tunnel(myrailsenv)

    # Copy the database.yml file
    # Note: the database.yml file will be removed automatically by the cbrain_remote_ctl script when it exits.
    copy_command = "cat > #{self.ssh_control_rails_dir.to_s.bash_escape}/config/database.yml"
    self.write_to_remote_shell_command(copy_command) { |io| io.write(db_yml) }

    # SSH command to start the console.
    start_command = "cd #{self.ssh_control_rails_dir.to_s.bash_escape}; script/cbrain_remote_ctl console -e #{myrailsenv.to_s.bash_escape}"
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
    num_workers       = myself.workers_instances.presence || 0

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
      :workers_expected          => num_workers,
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
  # of the Bourreau's workers and some task stats.
  def self.remote_resource_ping
    myself             = RemoteResource.current_resource

    # Worker info
    worker_pool        = WorkerPool.find_pool(BourreauWorker) rescue nil
    workers            = worker_pool.workers rescue nil
    worker_pids        = workers.map(&:pid).join(",") rescue '???'
    num_workers        = myself.workers_instances.presence || 0

    # Stats
    num_sync_userfiles  = myself.sync_status.count         # number of files locally synchronized
    size_sync_userfiles = myself.sync_status.joins(:userfile).sum("userfiles.size") # tot sizes of these files
    num_tasks           = myself.cbrain_tasks.count        # total number of tasks on this Bourreau
    num_active_tasks    = myself.cbrain_tasks.active.count # number of active tasks on this Bourreau

    info = super
    info[:worker_pids]                = worker_pids
    info[:workers_expected]           = num_workers
    info[:num_sync_cbrain_userfiles]  = num_sync_userfiles
    info[:size_sync_cbrain_userfiles] = size_sync_userfiles
    info[:num_cbrain_tasks]           = num_tasks
    info[:num_active_cbrain_tasks]    = num_active_tasks
    info
  end

  protected # internal methods for remote control operations above

  def build_db_yml_for_tunnel(railsenv) #:nodoc:
    myconfig = self.class.current_resource_db_config(railsenv) # a copy of the active config

    myconfig.delete "host"
    myconfig.delete "port"
    myconfig["socket"] = 'SUBSTITUTED_BY_BOURREAU_AT_BOOT_TIME'

    ymlstruct = Hash.new
    ymlstruct[railsenv.to_s] = myconfig.to_h

    yml = "\n" +
          "#\n" +
          "# File created automatically on Portal Side\n" +
          "# by " + self.revision_info.format("%f %s %a %d") + "\n" +
          "#\n" +
          "\n" +
          YAML.dump( ymlstruct )

    yml
  end



  ############################################################################
  # Utility Shortcuts To Send Commands
  ############################################################################

  public

  # Utility method to sends a +stop_yourself+ command to a
  # Bourreau RemoteResource, whether local or not.
  def send_command_stop_yourself
    command = RemoteCommand.new(
      :command     => 'stop_yourself',
    )
    send_command(command)
  end

  # Utility method to send a +get_task_outputs+ command to a
  # Bourreau RemoteResource, whether local or not.
  def send_command_get_task_outputs(task_id,run_number=nil,stdout_lim=nil,stderr_lim=nil)
    command = RemoteCommand.new(
      :command     => 'get_task_outputs',
      :task_id     => task_id.to_s,
      :run_number  => run_number,
      :stdout_lim  => stdout_lim,
      :stderr_lim  => stderr_lim,
    )
    send_command(command) # will return a command object with stdout and stderr
  end



  ############################################################################
  # Control Commands Implemented by Bourreaux
  ############################################################################

  protected

  # This comaand is a bit dangerous: it will first trigger a +stop_workers+
  # command to be sent locally, and then the rails app will kill itself with
  # a TERM signal, thus exiting right after the current request. The user should
  # really make sure the workers are inactive and there is no other background
  # activity.
  def self.process_command_stop_yourself(command)
    process_command_stop_workers(
      command.dup.tap { |com| com.command = "stop_workers" }
    )
    Process.kill('TERM',Process.pid) # the rails server will shut down after the current request
  end

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
       { :name           => "TaskWorker #{myself.name}",
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

  # Returns the STDOUT and STDERR of a task.
  def self.process_command_get_task_outputs(command)
    task_id    = command.task_id.to_i
    task = CbrainTask.find(task_id)
    run_number = command.run_number || task.run_number
    stdout_lim = command.stdout_lim
    stderr_lim = command.stderr_lim
    task.capture_job_out_err(run_number,stdout_lim,stderr_lim)
    command.cluster_stdout = task.cluster_stdout
    command.cluster_stderr = task.cluster_stderr
    command.script_text    = task.script_text
    command.runtime_info   = task.runtime_info
  rescue => e
    command.cluster_stdout = "Bourreau Exception: #{e.class} #{e.message}\n"
    command.cluster_stderr = "Bourreau Exception:\n#{e.backtrace.join("\n")}\n"
    command.script_text    = ""
    command.runtime_info   = ""
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
      blogger = Log4r::Logger['TaskWorker']
      unless blogger
        blogger = Log4r::Logger.new('TaskWorker')
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
      blogger = Log4r::Logger['TaskWorker']
      unless blogger
        blogger = Log4r::Logger.new('TaskWorker')
        blogger.add(Log4r::RollingFileOutputter.new('task_workers_outputter',
                      :filename  => "#{Rails.root}/log/TaskWorkers.combined..log",
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

  ############################################################################
  # Validation callbacks
  ############################################################################

  public

  def all_reverse_service_params_supplied
    return true if ! self.use_reverse_service?

    %i( reverse_service_user reverse_service_host reverse_service_port
        reverse_service_db_socket_path reverse_service_ssh_agent_socket_path )
    .each do |att|
      errors.add( att, "cannot be blank if the option to use the reverse service is selected") if
        self.send(att).blank?
    end
  end

end
