
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
  has_and_belongs_to_many :tools

  attr_accessor :operation_messages # no need to store in DB
  
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

    # If we tunnel the DB, we get a non-blank yml file here
    db_yml  = self.has_db_tunneling_info?   ?   self.build_db_yml_for_tunnel : ""

    # What port the Rails Bourreau will listen to?
    port = self.has_actres_tunneling_info?  ?   self.tunnel_actres_port : self.actres_port

    # What environment will it run under?
    myrailsenv = ENV["RAILS_ENV"] || "production"

    # File to capture command output.
    captfile = "/tmp/start.out.#{Process.pid}"
  
    # SSH command to start it up; we pipe to it either a new database.yml file
    # which will be installed, or "" which means to use whatever
    # yml file is already configured at the other end.
    start_command = "ruby #{self.ssh_control_rails_dir}/script/cbrain_remote_ctl"
                  + " start -e #{myrailsenv} -p #{port}"
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

  def build_db_yml_for_tunnel #:nodoc:
    myrailsenv = ENV["RAILS_ENV"] || "production"
    myconfigs  = ActiveRecord::Base.configurations
    myconfig   = myconfigs[myrailsenv].dup

    myconfig["host"]   = "127.0.0.1"
    myconfig["port"]   = self.tunnel_mysql_port
    myconfig.delete("socket")

    yml = "\n" +
          "#\n" +
          "# File created automatically on Portal Side\n" +
          "# by " + self.revision_info.svn_id_pretty_file_rev_author_date + "\n" +
          "#\n" +
          "\n" +
          "#{myrailsenv}:\n"
    myconfig.each do |field,val|
       yml += "  #{field}: #{val.to_s}\n"
    end
    yml += "\n"
   
    yml
  end



  ############################################################################
  # Commands Implemented by Bourreaux
  ############################################################################

  protected

  # Starts Bourreau worker processes.
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
      blogger = Log4r::Logger['BourreauWorker'] || Log4r::Logger.new('BourreauWorker')
      blogger.add(Log4r::Outputter.stdout) if log_to =~ /stdout/i
      blogger.add(Log4r::Outputter.stderr) if log_to =~ /stderr/i
      blogger.level = CBRAIN::BOURREAU_WORKERS_VERBOSE ? Log4r::DEBUG : Log4r::INFO

    # Option 3: combined log a file
    elsif log_to == 'combined'
      blogger = Log4r::Logger['BourreauWorker'] || Log4r::Logger.new('BourreauWorker')
      blogger.add(Log4r::RollingFileOutputter.new('bourreau_workers_outputter',
                    :filename  => "#{RAILS_ROOT}/log/BourreauWorkers.combined..log",
                    :formatter => Log4r::PatternFormatter.new(:pattern => "%d %l %m"),
                    :maxsize   => 1000000, :trunc => 600000))
      blogger.level = CBRAIN::BOURREAU_WORKERS_VERBOSE ? Log4r::DEBUG : Log4r::INFO

    # Option 4: use RAIL's own logger
    elsif log_to == 'bourreau'
      blogger = logger # Rails app logger
    end

    blogger
  end

  # NOTE: 'private' in effect here.

end
