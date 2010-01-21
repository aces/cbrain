
#
# CBRAIN Project
#
# This class implements a worker subprocess
# that manages the CBRAIN queue of tasks.
#
# Original author: Pierre Rioux
#
# $Id$
#

# = Bourreau Worker Class
#
# This class implements a worker subprocess
# that manages the CBRAIN queue of tasks.
# This model is not an ActiveRecord class.
class BourreauWorker

  Revision_info="$Id$"

  PIDfile_prefix="BouWork-"

  attr_accessor :pid, :pidfile_path, :check_interval, :bourreau, :log_to, :verbose

  # Get a list of all workers known to have been activated.
  # They may not all still be alive.
  def self.all
    # Because RAILS zaps the class variables when running in
    # development mode, I'm forced to store them in a global
    # variable instead of @@bourreau_workers like I'd like. Eh.
    $bourreau_workers ||= []
  end

  # Rebuild a list of currently active workers.
  # This is based on the list of PID files, and
  # a check is made to make sure that the subprocesses
  # are running. Dead workers (and their PID files)
  # are cleaned up.
  def self.rescan_workers
    $bourreau_workers = []
    Dir.chdir(self.piddir_path.to_s) do
      Dir.glob("#{PIDfile_prefix}*.run").each do |basepid|
        worker = self.new
        worker.pidfile_path = self.piddir_path + basepid
        if worker.validate_running_worker
          $bourreau_workers << worker
        end
      end
    end
    $bourreau_workers
  end

  # This method sends a +signal+ to all known active workers.
  # This method should not be used with signals that
  # kills this worker. If you need to kill a worker, use the
  # terminate() method instead, as it will properly
  # de-register it too.
  def self.signal_all(signal = 'USR1')
    self.all.dup.each { |bw| Process.kill(signal,bw.pid) rescue true }
    true
  end

  # This method send a wake up signal (USR1) to all known active workers.
  def self.wake_all
    self.signal_all('USR1')
    true
  end

  # This method stops (terminate) all known active workers.
  def self.stop_all
    self.all.dup.each { |w| w.terminate rescue true }
    true
  end

  def initialize #:nodoc:
    self.pid            = nil
    self.check_interval = 55 # seconds
    self.log_to         = 'stdout'  # bourreau,stdout (join keywords with commas)
    self.verbose        = false
    self
  end

  # Check that a subprocess is running for this
  # worker.
  def is_alive?
    self.check_unix_process
  end

  # Starts an asynchronous subprocess for the worker.
  # The PID is recorded in the parent's and child's
  # object.
  def launch
    if self.pid || $bourreau_workers.include?(self)
      raise "Cannot launch a Worker that seems to be already active!"
    end
    self.pid = CBRAIN.spawn_with_active_records(nil,"Bourreau Worker") do
      self.pid = $$
      Kernel.at_exit { delete_pidfile }
      begin
        record_pidfile_path
        write_pidfile
        mainloop
      ensure
        delete_pidfile
      end
    end
    record_pidfile_path
    $bourreau_workers ||= []
    $bourreau_workers << self
  end

  # Send a kill signal to the worker's subprocess.
  def terminate
    Process.kill("TERM",self.pid) if self.pid
    self.pid          = nil
    self.pidfile_path = ""
    $bourreau_workers.reject! { |w| w.object_id == self.object_id }
    true
  end

  # This method re-reads the PID file for
  # the worker, and makes sure that the process
  # with that PID is a worker. If not, it erases
  # the PID file. It returns true if we have
  # a proper running worker.
  def validate_running_worker #:nodoc:
    return false unless read_pidfile
    isrunning = self.check_unix_process
    self.delete_pidfile unless isrunning
    isrunning
  end

  # Log a message to stdout, or to
  # the bourreau's internal log,
  # as determined by the content of
  # the log_to instance variable.
  #
  # This method should only be called from inside
  # the worker subprocess itself, and very infrequently
  # too.
  def addlog(message)
    return unless self.log_to

    message = "Bourreau Worker #{self.pid}: " + message

    # Send log entry to Bourreau's internal log
    if self.bourreau && self.log_to.to_s =~ /bourreau/i
      self.bourreau.addlog(message)
    end

    # Send log entry to stdout
    if self.log_to.to_s =~ /stdout/i
      lines = message.split(/\s*\n/)
      lines.pop while lines.size > 0 && lines[-1] == ""
      message = lines.join("\n") + "\n"
      message = Time.now.strftime("[%Y-%m-%d %H:%M:%S] ") + message
      puts message
    end

  end

  protected



  ########################################################
  # Worker Processing
  ########################################################

  # This is the main loop for the worker's subprocess.
  # Every +check_interval+ seconds it scans the list of
  # active tasks (all subclasses of DrmaaTask) and
  # calls process_task() on them. It goes on until
  # the end of the world, or until the process is
  # sent SIGKILL or SIGTERM, or until the PID file is
  # removed by an external source, whichever comes first.
  def mainloop

    # Variables modified by signals
    go_on                   = true
    sleep_mode              = false

    # Sleep mode internal time limit variable
    sleep_mode_time_entered = Time.now

    # Signal handlers
    Kernel.trap("INT")  { self.addlog "Got SIGINT, scheduling stop."  ; go_on = false }
    Kernel.trap("TERM") { self.addlog "Got SIGTERM, scheduling stop." ; go_on = false }
    Kernel.trap("USR1") { self.addlog "Got SIGUSR1, waking up." if self.verbose && sleep_mode ; sleep_mode = false }

    # Starts main infinite loop
    self.addlog "Starting main worker loop."
    self.addlog "Revision " + self.revision_info.svn_id_pretty_rev_author_date
    sleep rand(3)

    while go_on

       # This is the eternal SLEEP mode when there is nothing to do; it
       # lets our process be responsive to signals while not querying
       # the database all the time for nothing.
       # This mode is reset to normal 'scan' mode when receiving a USR1 signal
       # or at least once every hour (so that there is at least some
       # kind of DB activity; some DB servers close their socket otherwise)
       if sleep_mode
         sleep 1
         # make sure we make ONE true scan every hour at least
         if Time.now - sleep_mode_time_entered > 3600
           self.addlog "Waking up from sleep mode for hourly protocolar DB check."
           sleep_mode = false
         end
         next
       end

       # Checks for disappearing PID file
       unless File.exist?(self.pidfile_path.to_s)
         self.addlog "PID file has been erased, stopping."
         go_on = false
         break
       end

       # Asks the DB for the list of tasks that need handling.
       tasks_todo = DrmaaTask.find(:all,
         :conditions => { :status      => [ 'New', 'Queued', 'On CPU', 'Data Ready' ],
                          :bourreau_id => CBRAIN::SelfRemoteResourceId } )

       # Detects and turns on sleep mode.
       if tasks_todo.size == 0
         self.addlog("No tasks need handling, going to eternal SLEEP state.") if verbose
         sleep_mode = true
         sleep_mode_time_entered = Time.now
         next
       end
       
       # Processes each task in the active list
       tasks_todo.each do |task|
         process_task(task) # this can take a long time...
         break unless go_on
       end

       break unless go_on
       sleep check_interval+rand(5) # Scan mode sleep interval.

    end
    self.addlog "Finishing properly."
  end

  # This is the worker method that executes the necessary
  # code to make a task go from state *New* to *Setting* *Up*
  # and from state *Data* *Ready* to *Post* *Processing*.
  #
  # It also updates the statuses from *Queued* to
  # *On* *CPU* and *On* *CPU* to *Data* *Ready* based on
  # the activity on the cluster, but no code is run for
  # these transitions.
  def process_task(task)
    begin
      mypid = self.pid # PID of the current worker process

      task.reload # Make sure we got it up to date
      self.addlog "--- Got #{task.bname_tid} in state #{task.status}" if verbose

      task.update_status # Queued -> On CPU ; On CPU -> Data Ready ; leaves all other alone.

      self.addlog "Updated #{task.bname_tid} to state #{task.status}" if verbose
      case task.status
        when 'New'
          task.addlog_context(self,"Setting Up, PID=#{mypid}")
          self.addlog "Start   #{task.bname_tid}"                         if verbose
          task.start_all  # New -> Queued|Failed To Setup
          self.addlog "     -> #{task.bname_tid} to state #{task.status}" if verbose
        when 'Data Ready'
          task.addlog_context(self,"Post Processing, PID=#{mypid}")
          self.addlog "PostPro #{task.bname_tid}"                         if verbose
          task.post_process # Data Ready -> Completed|Failed To PostProcess
          self.addlog "     -> #{task.bname_tid} to state #{task.status}" if verbose
      end

      if task.status == 'Completed'
        Message.send_message(task.user,
                             :message_type  => :notice,
                             :header        => "Task #{task.name} Completed Successfully",
                             :description   => "Oh great!",
                             :variable_text => "[[#{task.bname_tid}][/tasks/show/#{task.id}]]"
                            )
      elsif task.status =~ /^Failed/
        Message.send_message(task.user,
                             :message_type  => :error,
                             :header        => "Task #{task.name} Failed",
                             :description   => "Sorry about that. Check the task's log.",
                             :variable_text => "[[#{task.bname_tid}][/tasks/show/#{task.id}]]"
                            )
      end

    rescue => e
      self.addlog "Exception processing task #{task.bname_tid}: #{e.class.to_s} #{e.message}" +
                  e.backtrace[0..10].join("\n")
    end
  end



  ########################################################
  # System architecture specific methods
  ########################################################

  # Makes sure that a worker subprocess runs for
  # this worker.
  def check_unix_process #:nodoc:
    return false if self.pid.blank?
    begin
      lines = []
      command = case CBRAIN::System_Uname
        # Works on MacOS X and Linux
        when /^(Linux|Darwin)/
          "ps -o uid,command -p #{self.pid} 2>&1"
        # Works on Solaris
        when /Solaris/
          "ps -o uid,args -p #{self.pid} 2>&1"
        else # Just a guess.
          "ps -p #{self.pid} 2>&1"
        end
      IO.popen(command,"r") do |s|
        lines = s.read.split(/\n/)
      end
      lines.pop while lines.size > 0 && lines[-1].blank?
      if lines.size > 1 && lines[-1] =~ /^\s*(\d+).*(irb|ruby|mongrel|worker|bourreau w)/i
         other_uid = Regexp.last_match[1].to_i
         return true if other_uid == Process.uid || other_uid == Process.euid
      end
      return false
    rescue => e
      return false
    end
    false
  end
  


  ########################################################
  # PID file methods
  ########################################################

  def self.piddir_path #:nodoc:
    Pathname.new(RAILS_ROOT) + "tmp/pids"
  end

  def record_pidfile_path #:nodoc:
    self.pidfile_path = self.class.piddir_path + "#{PIDfile_prefix}#{self.pid}.run"
  end

  def write_pidfile #:nodoc:
    File.open(self.pidfile_path,"w") { |fh| fh.write(self.pid.to_s) }
  end

  def read_pidfile #:nodoc:
    filename = self.pidfile_path.to_s || ""
    if filename =~ /(\d+)\.run$/
      self.pid = Regexp.last_match[1].to_i
      return self.pid
    end
    self.pid = nil
  end

  def delete_pidfile #:nodoc:
    File.unlink(self.pidfile_path) rescue true
  end

end
