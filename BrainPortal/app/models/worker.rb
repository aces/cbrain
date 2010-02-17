
#
# CBRAIN Project
#
# Original authors: Pierre Rioux & Anton Zoubarev
#
# $Id$
#

require 'sys/proctable'
require 'log4r'

# = Worker Class
# This class is responsible for managing a separate UNIX worker subprocess.
# When a worker is started a new process is spawned meaning there will be two 'copies'
# of each object. One copy is inside the main process and acts as a ':proxy' to control
# the other one, which is running in the subprocess as the ':worker'.
#
# Some methods apply only to the :proxy object, while other apply only to the :worker.
#
# A typical real world worker is created by defining a subclass of Worker and
# providing one (or two) methods: do_regular_work() and finalize() (this last one
# is optional).
#
#   class MyWorker < Worker
#    def do_regular_work
#      puts "Doing work"
#    end
#   end
#
# Then a worker can be launched and monitored this way:
#
#   w = MyWorker.new( :check_interval => 4 ) # w is a :proxy
#   w.start
#   sleep 10
#   w.stop
#
# The code on the :worker side, in do_regular_work(), can inform or
# query the Worker superclass by calling these methods:
#
#   request_sleep_mode(interval = nil)
#   cancel_sleep_mode()
#   stop_signal_received?()
#   stop_me()
#   cancel_stop_me()
#
# The :proxy side can interact with the :worker side with
# these methods:
#
#   self.find_existing_workers()
#   start()
#   stop()
#   wake_up()
#   is_alive?()
#
class Worker
  include Sys
  include Log4r

  Revision_info="$Id$"

  PIDFILES_DIR = Pathname.new(RAILS_ROOT) + "tmp/pids"
  LOGFILES_DIR = Pathname.new(RAILS_ROOT) + "log"

  # --- Public attributes ---
  public

  # A name for the worker; this will be assigned
  # to the content of $0 in the worker process,
  # so it should be a simple identifier, likely
  # limited to 9 characters long on many OSes.
  # The default name is the worker's class.
  attr_accessor :name
  # Process id of the worker process. When the object
  # is the worker, this corresponds to Process.id; when
  # the object is the proxy, it's the PID of the child worker.
  attr_accessor :pid
  # Path to the pidfile associated with worker subprocess.
  attr_accessor :pidfile
  # How frequently the worker's code is to be invoked (in seconds)
  attr_accessor :check_interval
  # Our personal logger; can be supplied externally,
  # or internally as a Log4r::Logger object (set it to :auto)
  # A nil value disables logging.
  attr_accessor :worker_log
  # Log level for logger when supplied internally (Log4r constant)
  # The default (very verbose) value is Log4r::DEBUG
  attr_accessor :log_level
  # A CBRAIN User or Group used for notification with Message
  # if an exception occurs in the worker. The default is nil,
  # no notification to be performed.
  attr_accessor :message_notifiee

  # --- Protected attributes ---
  protected

  # Our role; one of :proxy or :worker
  attr_accessor :role
  # Records whether or not we are scheduled for shutdown
  attr_accessor :stop_received
  # Records whether or not we are scheduled for sleep mode
  attr_accessor :sleep_mode
  # Sleep interval: in sleep mode, how long we sleep.
  attr_accessor :sleep_interval

  # Return to public context
  public

  # A new worker can be initialized by supplying a hash table
  # with the following attributes:
  #
  #  :check_interval => 10,             # Number of seconds between each call to do_regular_work().
  #
  #  :worker_log     => logger_object,  # An Log4r compatible object; must answer to .debug, .info,
  #                                     # .warn and .fatal; the keyword :auto can be supplied
  #                                     # to let the class configure one automatically.
  #
  #  :log_level      => Log4r::DEBUG    # If :auto was provided to :worker_log, the log level for it.
  #
  #  :name           => 'Xyz',          # A name saved in Worker's $0; will show up with 'ps'.
  #
  #  :message_notifiee => => u_or_g     # A CBRAIN User or Group; will receive the 'Internal Error
  #                                     # Message' if an exception is raised in the worker.
  #
  # The attributes can be set by calling methods of the same names,
  # too. Note that once a worker is started, there is no way on
  # the :proxy side to change the worker's  attributes, as it is
  # now a separate subprocess. The :worker side should avoid modifying
  # ANY of its attributes.
  def initialize(initializers = {})
    self.pidfile        = ""
    self.pid            = nil
    self.role           = :proxy
    self.check_interval = 10
    self.sleep_interval = nil
    self.stop_received  = nil
    init_copy = initializers.dup
    [ :check_interval, :log_level, :worker_log, :name, :message_notifiee ].each do |key|
      self.send("#{key.to_s}=", init_copy[key]) if init_copy.has_key?(key)
      init_copy.delete(key)
    end
    cb_error "Unknown initializers for Worker: #{init_copy.keys.join(", ")}" if init_copy.keys.size > 0
  end

  # Proxy-side class method.
  #
  # Find running workers of the current subclass.
  # Returns an array of proxy objects.
  def self.find_existing_workers
    workers = []
    # We construct pattern that matches pidfiles: "some_prefix-*.run"
    match_pidfiles = self.construct_pidfile_name("*")
    Dir.chdir(PIDFILES_DIR.to_s) do
      Dir.glob(match_pidfiles).each do |pidfile|
        worker = self.new
        worker.initialize_from_pidfile(pidfile)
        workers << worker if worker.is_alive?
      end
    end
    return workers
  end



  ##################################################################################
  # This is the interface to control the worker from the process that spawned it.
  # When a worker process is spawned a worker object continues to live on the
  # rails app side, the ':proxy'. Using this object it is possible to
  # control the worker process, the ':worker'.
  ##################################################################################

  # Proxy-side method.
  #
  # Starts a process for the worker.
  # Initializes its logger, registers signal handlers and records +pid+ and +pidfile+.
  def start
    self.validate_I_am_a_proxy
    return true if self.is_alive?

    # Default name
    self.name = self.class.to_s unless self.name

    # We are saving pid in the worker 'proxy' instance that stays on rails app side.
    self.pid = CBRAIN.spawn_with_active_records(self.message_notifiee,self.name) do

      # This block is excecuted by the newly created worker process.
      self.pid = Process.pid # the worker's PID now
      self.role = :worker
      @pretty_name = nil # need to be reset as it is cached inside pretty_name()
      Kernel.at_exit { self.delete_pidfile }

      begin
        # This sleep is needed unfortunately to give the time for the
        # proxy side to call its own create_pidfile() so that a quick
        # succession of start() followed by is_alive?() returns true.
        sleep 5  # TODO: re-engineer this potential race_condition.

        # Initialize logger
        if self.worker_log && self.worker_log.is_a?(Symbol) && self.worker_log == :auto
          log = Logger.new self.pretty_name
          log.outputters = FileOutputter.new('log_file_outputter',
                             :filename  => "#{LOGFILES_DIR}/#{self.pretty_name}.log",
                             :formatter => PatternFormatter.new(:pattern => "%d %l %m"),
                             :trunc     => false)
          log.level=self.log_level || Log4r::DEBUG
          self.worker_log = log
          self.patch_logger # auto prefix messages in logger with pretty_name()
        elsif self.worker_log.blank?  # Null logger, ignores everything
          self.worker_log = Logger.root
        else # Using custom logger!
          cb_error "Logger object doesn't seem to support methods debug(), info() etc..." unless
            self.worker_log.respond_to?(:debug) && self.worker_log.respond_to?(:info)
          self.patch_logger # auto prefix messages in logger with pretty_name()
        end

        # Initialize variables modified by signals
        self.stop_received  = false
        self.sleep_mode     = false
        self.sleep_interval = self.check_interval * 10 if self.sleep_interval.blank?

        # Register signal handlers
        Signal.trap("INT") do
          self.worker_log.info "Got SIGINT, scheduling stop."
          self.stop_received = true
          self.sleep_mode    = false
        end

        Signal.trap("TERM") do
          self.worker_log.info "Got SIGTERM, scheduling stop."
          self.stop_received = true
          self.sleep_mode    = false
        end

        Signal.trap("USR1") do
          self.worker_log.debug "Got SIGUSR1, waking up worker if asleep."
          self.sleep_mode    = false
        end

        self.worker_log.debug "Registered signal handlers for INT, TERM and USR1."

        # Create pidfile
        self.create_pidfile # will crush the pidfile created by proxy; see race_condition.

        # Execute method that does regular work (implemented by subclasses of Worker)
        self.main_loop

      # Raise exceptions back to the spawn method so it can send a Message
      rescue => itswrong
        raise itswrong

      # Must delete the PID file no matter what
      ensure
        self.delete_pidfile

      end # end of 'begin'
    end # Worker process wrapper ends here

    # We also need to store pidfile on rails app side
    #self.pidfile = self.class.construct_pidfile_name(self.pid)
    self.create_pidfile  # TODO: see race_condition above.
  end

  # Proxy-side method.
  #
  # Send a kill signal to the worker process.
  # The worker will stop at the end of its current
  # iteration of do_regular_work(), or right away if
  # it is in sleep mode or in between checks.
  def stop
    self.validate_I_am_a_proxy
    cb_error "Worker '#{self.pretty_name}' API error: no PID found for worker?!?"   unless self.pid
    Process.kill('TERM', self.pid)
  end

  # Proxy-side method.
  #
  # Send wake up signal to the worker process.
  # Will have no effect on a worker that is not
  # in sleep mode.
  def wake_up
    self.validate_I_am_a_proxy
    cb_error "Worker '#{self.pretty_name}' API error: no PID found for worker?!?"   unless self.pid
    Process.kill('USR1', self.pid)
  end

  # Proxy-side method.
  #
  # Check that a process is running for this worker and pid file exists.
  def is_alive?
    self.validate_I_am_a_proxy
    return pidfile_exists? && process_ok?
  end

  # Utility method that returns a nice identifier
  # for the worker, in the form of "{classname}-{pid}"
  def pretty_name
    @pretty_name ||= "#{self.class}-#{self.pid}"
  end

  protected

  # Makes sure that a process runs for this worker-proxy.
  def process_ok? #:nodoc:
    self.validate_I_am_a_proxy
    unless self.pid.blank?
      process_info = ProcTable.ps(self.pid)
      if process_info
        procuid   = process_info.ruid rescue nil
        procuid ||= process_info.uid rescue nil
        if procuid && (Process.uid == procuid || Process.euid == procuid)
          return true
        end
      end
    end
    self.delete_pidfile
    return false
  end

  # Main worker loop. +do_regular_work+ and +finalize+ are provided by subclasses.
  def main_loop #:nodoc:
    self.validate_I_am_a_worker
    self.worker_log.info "Starting main worker loop."
    self.worker_log.info "Revision " + self.revision_info.svn_id_pretty_rev_author_date

    # Infinite worker loop start here
    until self.stop_received

      # Check for disappearing PID file
      unless pidfile_exists?
        self.worker_log.info "PID file has been erased, stopping."
        break
      end

      # Do some work implemented by subclass.
      # Exceptions will cause the worker to quit.
      self.do_regular_work
      break if self.stop_received

      # We have two modes 'wait' modes.
      #
      # The 'check_interval' mode is the rate at which the
      # worker's do_regular_work() method is invoke in normal
      # times. While waiting in this mode, we cannot be awakened
      # but can we can be stopped.
      #
      # The 'sleep_interval' mode is an unusual (longer)
      # interval that can be triggered ONCE, by the worker itself,
      # to tell this class that it is slowing down. The
      # sleep period can be interrupted at any time by an
      # external program, to wake up or sotp the worker.
      if self.sleep_mode && ! self.sleep_interval.blank?
        self.sleep_for_requested_interval
      elsif ! self.check_interval.blank?
        self.wait_for_requested_interval
      else
        cb_error "Worker '#{self.pretty_name}' API error: no sleep mode and no check_interval supplied?"
      end

    end # end of infinite worker loop.

    # Custom finalization method supplied by subclass.
    self.finalize

    # End of worker.
    self.worker_log.info "Finishing main worker loop."

  # Error handling: all errors at this level are fatal.
  # It is the responsability of the worker subclass to deal
  # with its own errors and trap them.
  rescue => itswrong

    self.worker_log.fatal "Exception raised: #{itswrong.class} : #{itswrong.message}"
    itswrong.backtrace.each do |line|
      self.worker_log.fatal line
    end
    self.worker_log.fatal "Worker shutting down."

    # So that the Messaging handler in spawn_with_active_records() informs
    # the owner.
    if self.message_notifiee
      what = self.message_notifiee.class.to_s
      who  = self.message_notifiee.login rescue self.message_notifiee.name
      self.worker_log.fatal "Message sent to #{what} '#{who}'"
      raise itswrong
    end

  end

  # Put worker into sleep mode.
  def sleep_for_requested_interval #:nodoc:
    self.validate_I_am_a_worker
    time_to_wake_up = self.sleep_interval.from_now
    self.worker_log.debug "Entering sleep mode for #{self.sleep_interval} seconds."
    while self.sleep_mode && ! self.stop_received
      sleep 1
      break if Time.now >= time_to_wake_up	
    end
    self.sleep_mode = false # sleep mode is a one shot mode.
    if Time.now >= time_to_wake_up
       self.worker_log.debug "Sleep mode finished (full sleep accomplished)."
    else
       self.worker_log.debug "Waking up from sleep mode with #{time_to_wake_up.to_i - Time.now.to_i} seconds left."
    end
  end

  # Put worker into normal wait mode.
  # Unlike sleep mode, cannot be awakened.
  def wait_for_requested_interval #:nodoc:
    self.validate_I_am_a_worker
    time_to_wake_up = self.check_interval.from_now
    self.worker_log.debug "Waiting for next check."
    while ! self.stop_received
      sleep 1
      break if Time.now >= time_to_wake_up	
    end
    self.worker_log.debug "Ready for next check."
  end

  # Patch logger through a transparent interface so that
  # the worker's pretty_name is always prefixed to all messages.
  def patch_logger #:nodoc:
    self.validate_I_am_a_worker
    prefixer = LoggerPrefixer.new
    prefixer.true_logger = self.worker_log
    prefixer.prefix      = self.pretty_name + ": "
    self.worker_log      = prefixer
  end



  #####################################################################
  # These methods are meant to be used inside +do_regular_work+
  #####################################################################

  # Worker-side method.
  #
  # Request sleep mode until +interval+ is over
  # or until either a wake up or stop signal is received.
  # If a sleep mode interval is not supplied in argument,
  # the previous value for the interval is used. The default
  # sleep mode interval is initially set to 10 times the
  # current check_interval.
  #
  # This method only registers that sleep mode is asked for,
  # but does not actually sleep at all. The sleep mode will be
  # entered once do_regular_work() returns, in place of the
  # normal check_interval waiting period.
  def request_sleep_mode(interval = nil)
    self.validate_I_am_a_worker
    if interval
       self.sleep_interval = interval
    elsif self.sleep_interval.blank?
       self.sleep_interval = self.check_interval * 10
    end
    self.sleep_mode = true
  end

  # Worker-side method.
  #
  # Just in case a worker changes its mind about sleep mode
  def cancel_sleep_mode
    self.validate_I_am_a_worker
    self.worker_log.debug "Cancelling sleep mode."
    self.sleep_mode = false
  end

  # Worker-side method.
  #
  # Returns true if an external or internal stop signal was received.
  # If the worker's do_regular_work() method calls stop_signal_recived?
  # and gets a true value then it means that the worker is scheduled
  # to stop completely as soon as do_regular_work() returns.
  def stop_signal_received?
    self.validate_I_am_a_worker
    self.stop_received
  end

  # Worker-side method.
  #
  # Call this to stop the process once do_regular_work() returns.
  def stop_me
    self.validate_I_am_a_worker
    self.worker_log.debug "Requesting own stopping."
    self.stop_received=true
  end

  # Worker-side method.
  #
  # Call this to cancel the effect of stop_me().
  def cancel_stop_me
    self.validate_I_am_a_worker
    self.worker_log.debug "Cancelling own stopping."
    self.stop_received=false
  end

  # Worker-side method.
  #
  # Can be overriden to do some cleanup after a worker
  # finishes. This method will not be invoked if the
  # worker ended because of a raised exception, only
  # after a normal 'stop' is performed.
  def finalize
    self.validate_I_am_a_worker
    self.worker_log.debug "No finalization needed."
  end

  # Worker-side method.
  #
  # Must be overriden in subclass.
  # This is the main place where a worker's actual
  # behavior is implemented. It will be called regularly
  # every +check_interval+ seconds. This method should
  # not loop-and-wait (the Worker class will take
  # care of that) and should not busy-wait.
  def do_regular_work
    self.validate_I_am_a_worker
    cb_error "Worker implementation error: no method do_regular_work() implemented?"
  end



  ########################################################
  # Process separation enforcement methods
  ########################################################

  def validate_I_am_a_worker #:nodoc:
    if self.role != :worker
      #./worker.rb:256:in `main_loop'
      caller[1] =~ /([^\/]\S*\:\d+):in `(\S+)'\s*$/
      mycontext = Regexp.last_match[2] + "() at " + Regexp.last_match[1]
      cb_error "Worker '#{self.pretty_name}' API error: method '#{mycontext}' called from proxy?!?"
    end
  end

  def validate_I_am_a_proxy #:nodoc:
    if self.role != :proxy
      #./worker.rb:256:in `main_loop'
      caller[1] =~ /([^\/]\S*\:\d+):in `(\S+)'\s*$/
      mycontext = Regexp.last_match[2] + "() at " + Regexp.last_match[1]
      cb_error "Worker '#{self.pretty_name}' API error: method '#{mycontext}' called from worker?!?"
    end
  end



  ########################################################
  # PID file related methods
  ########################################################

  # Get pid from pidfile name.
  # Assumes filename has '*pid.run' format.
  def self.extract_pid_from_pidfile_name(filename) #:nodoc:
    if filename =~ /(\d+)\.run$/
      return Regexp.last_match[1].to_i
    else
      return nil
    end
  end

  # Constructs pidfilename based on worker class and pid.
  # File name format: Worker-{WorkerClass}-{pid}.run
  # This method is also used to build a glab pattern
  # by calling it with the pid argument set to '*'.
  def self.construct_pidfile_name(pid) #:nodoc:
    return "Worker-#{self.to_s}-#{pid}.run"
  end

  def create_pidfile #:nodoc:
    self.pidfile = self.class.construct_pidfile_name(self.pid)
    fullpath = (PIDFILES_DIR + self.pidfile).to_s
    File.open("#{fullpath}.tmp","w") { |fh| fh.write(self.to_yaml) }
    File.rename("#{fullpath}.tmp",fullpath)
  end

  def delete_pidfile #:nodoc:
    return false if self.pidfile.blank?
    File.unlink((PIDFILES_DIR + self.pidfile).to_s) rescue false
  end

  def pidfile_exists? #:nodoc:
    self.pidfile.blank? ? false : File.exist?((PIDFILES_DIR + self.pidfile).to_s)
  end

  public # Needs to be public as it's called from class method find_existing_workers()

  # Initializes a proxy object using a +pidfile+.
  def initialize_from_pidfile(pidfile) #:nodoc:
    self.pidfile        = pidfile
    self.pid            = self.class.extract_pid_from_pidfile_name(pidfile)
    self.role           = :proxy
  end

end

class LoggerPrefixer
  attr_accessor :true_logger
  attr_accessor :prefix
  def debug(message)
    true_logger.debug(prefix + message)
  end
  def info(message)
    true_logger.info(prefix + message)
  end
  def warn(message)
    true_logger.warn(prefix + message)
  end
  def error(message)
    true_logger.error(prefix + message)
  end
  def fatal(message)
    true_logger.fatal(prefix + message)
  end
end

Log4r::Logger.new("dummy") && true # needed so that the constants Log4r::INFO, DEBUG etc appear!

