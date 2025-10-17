
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

# This class provides the functionality necessary to create,
# destroy and manage persistent SSH master (control) connections
# to other hosts.
#
# Original author: Pierre Rioux

require 'fcntl'
require 'rubygems'
require 'sys/proctable'
require 'active_support'

# = SSH Tunnel Utility Class
#
# This class provides the functionality necessary to create,
# destroy, and manage persistent SSH master (control) connections
# to other hosts. Each master connection can be configured with
# a set of tunnels.
#
# Tunnels are tied to a master, persistent SSH process running in
# a subprocess; the master SSH process is controlled using the
# instance methods of this class, where each instance represent
# one of these master SSH process. There can only be at most
# one master SSH process per combination of remote host,
# remote user and remote port, and this class ensures this
# by registering internally all instance objects created
# during new().
#
# Assuming SSH keys have been exchanged already, a ruby program
# can setup and manage a tunnel this way. Let's say the remote
# host 'my.example.com' is behind a firewall and runs a HTTP server
# on port 8080 that we would like to access, even though this port
# is not visible from here.
#
#    master = SshMaster.new('john','my.example.com',22)
#    master.add_tunnel(:forward,1234,'localhost',8080)
#    master.start
#    # Now we can connect to port 1234 locally and see the web server.
#    # Later on, even if we have lost the variable 'master'
#    # above, we can find it again to kill the tunnel:
#    master = SshMaster.find('john','my.example.com',22)
#    master.stop
#
# The master SSH process uses connection sharing to improve
# connection latency; this is accomplished by allocating UNIX
# domain sockets in /tmp; see also the ControlMaster and
# ControlPath options in SSH's manual (in particular, for
# the man page ssh_config, and for the '-o' option of 'ssh').
class SshMaster

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Class configuration variables.
  CONFIG = {

    # Location of sockets and PID files
    :CONTROL_SOCKET_DIR_1 => (Rails.root rescue nil) ? "#{Rails.root.to_s}/tmp/sockets" : "/tmp",

    # Alternate location if DIR_1 path is too long (control path MUST be < (max length below)  characters long!)
    :CONTROL_SOCKET_DIR_2 => "/tmp",

    # Limit on control socket length; in the SSH suite the limit is hardcoded to 100,
    # and in some platforms a temporary extension of 20 more characters are added while
    # it is being created, so we end up with a limit of about 80.
    :CONTROL_SOCKET_MAX_LENGTH => 80,

    # PID files location
    :PID_DIR              => (Rails.root rescue nil) ? "#{Rails.root.to_s}/tmp/pids" : "/tmp",

    # Internal timing limits; conservative enough and should not need to be changed.
    :IS_ALIVE_TIMEOUT     => 60,
    :SPAWN_WAIT_TIME      => 40,
  }

  # Ssh options defaults; these must be legal options as defined in ssh_config(5) and
  # will be inserted in the ssh command line as a series of "-o key=value". These options
  # are used for both permanent SSH masters and transient ones too.
  DEFAULT_SSH_CONFIG_OPTIONS = {
    :ConnectTimeout                 => 10,
    :StrictHostKeyChecking          => :no,
    :ExitOnForwardFailure           => :yes,
    :IPQoS                          => 'throughput',
    # The following options started to cause failures
    # when remote hosts' sshd_config started to refuse
    # key authentication even when no keyboards were detected.
    # (First seen, around 2020)
    # So I'm removing them from the default set of options. This
    # problem happens even though this lib never uses password
    # authentication, unfortunately.
    # Maybe sshd will be fixed in the future and this will start
    # working again.
    #:BatchMode                      => :yes,
    #:PasswordAuthentication         => :no,
    #:KbdInteractiveAuthentication   => :no,
    #:KbdInteractiveDevices          => :none,
  }.with_indifferent_access

  # ---------------------------------------------
  # Advanced options for instances of SshMaster
  # ---------------------------------------------

  # if true, turn on verbose logging of subprocess tracking stuff
  attr_accessor :debug

  # if true, no .oer files if created for diagnostics or logging
  attr_accessor :no_diag

  # returns true if the SshMaster object was created with option :nomaster
  attr_reader   :nomaster

  # Other options from ssh_config; must be a hash of
  # key/values, each one will be added as a "-o key=val" on the
  # master's command-line. Values of 'nil' can be used to remove
  # options already existing or provided by DEFAULT_SSH_CONFIG_OPTIONS
  attr_accessor :ssh_config_options

  # This class method allows you to find out and fetch the
  # instance object that represents a master connection to a
  # remote host (there can only be a single master for
  # each quintuplets [user,host,port,category,uniq] so we might
  # as well remember the objects in the class).
  def self.find(remote_user,remote_host,remote_port=22,options={:category=>nil,:uniq=>nil})
    remote_port ||= 22
    category = options[:category]
    uniq     = options[:uniq]
    key = "#{remote_user}@#{remote_host}:#{remote_port}"
    key = "#{category}/#{key}" if category && category.to_s =~ /\A\w+\z/
    key = "#{key}/#{uniq}"     if uniq     && uniq.to_s     =~ /\A\w+\z/
    ssh_masters = self.ssh_master_cache
    ssh_masters[key]
  end

  # TODO: Use Rails caching ?
  def self.ssh_master_cache #:nodoc:
    #@@ssh_masters ||= {}
    #@@ssh_masters
    $cbrain_ssh_masters ||= {}  # rails reload the class every time so can't use @@ssh_masters
    $cbrain_ssh_masters
  end

  def ssh_master_cache #:nodoc:
    self.class.ssh_master_cache
  end

  # This method is like find() except that it will create
  # the necessary control object if necessary.
  def self.find_or_create(remote_user,remote_host,remote_port=22,options={:category=>nil,:uniq=>nil})
    remote_port ||= 22
    masterobj = self.find(remote_user,remote_host,remote_port,options) ||
                self.new( remote_user,remote_host,remote_port,options)
    masterobj
  end

  # Works like find, but expect a single +key+
  # in a format like "user@host:port".
  # If a +category+ string was supplied when initializing
  # the object, the format of the key is "category/user@host:port".
  # If a +uniq+ string was supplied when initializing
  # the object, the format of the key is "user@host:port/uniq".
  # If both were supplied, the key is "category/user@host:port/uniq"
  def self.find_by_key(key)
    ssh_masters = self.ssh_master_cache
    ssh_masters[key]
  end

  # Returns all the configured SSH connections (not all
  # of them may be alive).
  def self.all
    ssh_masters = self.ssh_master_cache
    ssh_masters.values
  end

  # Returns an array containing all the keys for the currently
  # configued master SSH connections (not all of them
  # may be alive). Keys are strings like "user@host:port".
  def self.all_keys
    ssh_masters = self.ssh_master_cache
    ssh_masters.keys
  end

  def self.destroy_all #:nodoc:
    ssh_masters = self.ssh_master_cache
    ssh_masters.values.each { |tun| tun.destroy }
  end

  # Create a control object for a potential master to
  # host +host+, as user +user+ with SSH port +port+.
  # The master is NOT started. The object is registered
  # in the class and can be found later using the
  # find() class method. This means that projects using
  # this library do not have to save the control object
  # anywhere.
  def initialize(remote_user,remote_host,remote_port=22,options={:category=>nil,:uniq=>nil})

    @user       = remote_user
    @host       = remote_host
    @port       = (remote_port.presence || 22).to_i
    @category   =   options[:category]
    @uniq       =   options[:uniq]
    @nomaster   = !!options[:nomaster]

    @ssh_config_options = DEFAULT_SSH_CONFIG_OPTIONS
                          .dup
                          .merge(options[:ssh_config_options] || {})

    raise "SSH master's \"user\" is not a simple identifier." unless
      @user =~ /\A[a-zA-Z0-9][a-zA-Z0-9_\-\.]*\z/
    raise "SSH master's \"host\" is not a simple host name." unless
      @host =~ /\A[a-zA-Z0-9][a-zA-Z0-9_\-\.]*\z/
    raise "SSH master's \"port\" is not a port number." unless
      @port > 0 && @port < 65535
    raise "SSH master's \"category\" is not a simple identifer." unless
      @category.nil? || (@category.is_a?(String) && @category =~ /\A\w+\z/)
    raise "SSH master's \"uniq\" is not a simple identifer." unless
      @uniq.nil? || (@uniq.is_a?(String) && @uniq =~ /\A\w+\z/)

    raise "This master spec is already registered with the class." if
      self.class.find(@user,@host,@port, :category => @category, :uniq => @uniq )

    @pid             = nil
    @forward_tunnels = []   # [ "localhost", 1234, "some.host", 4566 ]
    @reverse_tunnels = []   # [ "localhost", 1234, "some.host", 4566 ]

    # Register it
    @simple_key = @key = "#{@user}@#{@host}:#{@port}"
    @key        = "#{@category}/#{@key}" if @category && @category.to_s =~ /\A\w+\z/
    @key        = "#{@key}/#{@uniq}"     if @uniq     && @uniq.to_s     =~ /\A\w+\z/
    ssh_masters = self.ssh_master_cache
    ssh_masters[@key] = self
    debugTrace("Registering SSH master: #{@key}")

    # Check to see if a process already manage the master
    self.read_pidfile

    self
  end

  # Add tunnel definitions to the master SSH connection. An arbitrary
  # number of forward or backward tunnels can be added; they
  # will be enabled once the start() method is called.
  #
  # [*direction*] is either :forward or :reverse
  # [*accept_port*] is a port number at the accepting end
  #                 of the tunnel; if direction is :forward then the
  #                 accepting end is the local machine (localhost); if
  #                 the direction is :reverse then it will be on
  #                 the +remote_host+ specified when creating the object
  #                 (which is NOT the +dest_host+)
  # [*dest_host*] is the hostname that will get connected to
  #               from the +remote_host+, through the tunnel, when
  #               accessing +accept_port+ at the accepting end.
  # [*dest_port*] is the port number that will get connected to on
  #               the +dest_host+, from the +remote_host+.
  # [*accept_bind*] is an optional binding address for the +accept_port+;
  #               the default value is 'localhost'.
  #
  # The argument list described above applies when both the source
  # and destination of the tunnels are network socket. But either
  # of them can also be configured as UNIX sockets.
  #
  # On the accept side, this is accomplished by setting +accept_bind+ to nil
  # and providing a path to the socket in +accept_port+ .
  #
  # On the destination side, this is accomplished by setting +dest_host to nil
  # and providing a path to the socket in +dest_port+ .
  #
  # Note that SSH will create the accept-side socket as needed,
  # but the destination side socket is supposed to have already
  # been set up by whatever is using it.
  def add_tunnel(direction, accept_port, dest_host, dest_port, accept_bind = "localhost")

    self.properly_registered?

    raise "'direction' must be :forward or :reverse." unless
      direction == :forward || direction == :reverse

    if ! accept_bind.nil?
      # Checks for network socket arguments
      raise "'accept_port' must be a port number > 1024 and < 65535." unless
        accept_port.is_a?(Integer) && accept_port > 1024 && accept_port < 65535
      raise "'accept_bind' is not a simple host name or IP." unless
        accept_bind =~ /\A[a-zA-Z0-9][a-zA-Z0-9\-\.]*\z/
    else
      # Checks for UNIX-domain socket arguments (accept_bind is nil)
      raise "'accept_port' cannot look like a number if using a UNIX socket." if
        accept_port.to_s =~ /^\d+$/
      socketpath = Pathname.new(accept_port)
      if direction == :forward && socketpath.exist?
        raise "Socket path for accept side already exists: #{accept_port}"
      end
    end

    if ! dest_host.nil?
      # Checks for network socket arguments
      raise "'dest_port' must be a port number." unless
        dest_port.is_a?(Integer) && dest_port > 0 && dest_port < 65535
      raise "'dest_host' is not a simple host name or IP." unless
        dest_host =~ /\A[a-zA-Z0-9][a-zA-Z0-9\-\.]*\z/
    else
      # Checks for UNIX-domain socket arguments (dest_host is nil)
      raise "'dest_port' cannot look like a number if using a UNIX socket." if
        dest_port.to_s =~ /^\d+$/
      #socketpath = Pathname.new(dest_port)
      #if direction == :reverse && ! socketpath.exist?
      #  raise "Socket path for destination does not seem to exist: #{dest_port}"
      #end
    end

    tunnel_spec = [ accept_bind, accept_port, dest_host, dest_port ]
    if direction == :forward
      if @forward_tunnels.find { |spec| spec[1] == accept_port }
        raise "Error: there's already a forward tunnel configured for port #{accept_port}."
      end
      @forward_tunnels << tunnel_spec
    else
      if @reverse_tunnels.find { |spec| spec[1] == accept_port }
        raise "Error: there's already a reverse tunnel configured for port #{accept_port}."
      end
      @reverse_tunnels << tunnel_spec
    end
    true
  end

  # Get the list of currently configured tunnels (note that they
  # may not be active; only tunnels present at the moment that
  # start() was called will be active). The returned value is
  # an array of quadruplets like this:
  #    [ accept_bind, accept_port, dest_host, dest_port ]
  # When the accept side is a UNIX socket, +accept_bind+ will
  # be nil. In the same way, if the destination side is a socket,
  # the +dest_host+ will be nil.
  def get_tunnels(direction)
    raise "'direction' must be :forward or :reverse." unless
      direction == :forward || direction == :reverse
    return direction == :forward ? @forward_tunnels.dup : @reverse_tunnels.dup
  end

  # This is like get_tunnels, except the returned array
  # contains strings where the four components are separated by
  # colons, such as "localhost:1234:myhost:5678".
  def get_tunnels_strings(direction)
    tunnels = self.get_tunnels(direction)
    tunnels.map { |s| s.compact.join(":") }
  end

  # Delete the list of tunnels specifications from the object.
  # Note that this does not affect the running master SSH, the
  # tunnels will be reset only after a stop() and start() cycle.
  def delete_tunnels(direction)
    raise "'direction' must be :forward or :reverse." unless
      direction == :forward || direction == :reverse
    if direction == :forward
      @forward_tunnels = []
    else
      @reverse_tunnels = []
    end
    true
  end

  # Adds the configuration for using a jumphost before
  # reaching the actual host defined during initialize().
  # Optional. Only a single jumphost is supported here.
  def add_jumphost(username, hostname, port = 22)

    self.properly_registered?

    @jumphost_user = username.to_s
    @jumphost_host = hostname.to_s
    @jumphost_port = (port.presence || 22).to_i

    raise "SSH master's jumphost \"user\" is not a simple identifier." unless
      @jumphost_user =~ /\A[a-zA-Z0-9][a-zA-Z0-9_\-\.]*\z/
    raise "SSH master's jumphost \"host\" is not a simple host name." unless
      @jumphost_host =~ /\A[a-zA-Z0-9][a-zA-Z0-9_\-\.]*\z/
    raise "SSH master's jumphost \"port\" is not a port number." unless
      @jumphost_port > 0 && @jumphost_port < 65535

    self
  end

  # Remove the jumphost configuration that was added by
  # add_jumphost().
  def delete_jumphost
    self.properly_registered?
    @jumphost_user = @jumphost_host = @jumphost_port = nil
    self
  end

  # Returns the string that will be used on the ssh command line
  # for the -J option of jumphost, e.g. "lois@superman.example.com:22"
  def get_jumphost_string
    return nil unless @jumphost_user.present?
    "#{@jumphost_user}@#{@jumphost_host}:#{@jumphost_port}"
  end

  # Start the master SSH connection, including all tunnels if
  # necessary. The connection is maintained in a subprocess.
  # If a subprocess is already running, nothing will happen:
  # you have to stop() if before you can restart it.
  def start(label = nil)

    self.properly_registered?
    return true if @nomaster # special option: not a master at all!
    return true if self.read_pidfile

    sshcmd = "ssh -q -n -N -x -M "

    if ! label.blank? && label.to_s =~ /\A[\w\-\.\+]+\z/
      sshcmd += "-o SendEnv=#{label.to_s} "
    end

    self.get_tunnels_strings(:forward).each { |spec| sshcmd += " -L #{spec}" }
    self.get_tunnels_strings(:reverse).each { |spec| sshcmd += " -R #{spec}" }

    jumphost_spec = self.get_jumphost_string()
    sshcmd += " -J #{jumphost_spec} " if jumphost_spec

    shared_options = self.ssh_shared_options("yes") # ControlMaster=yes
    sshcmd += " #{shared_options}"

    # 0 in the pidfile means in the process of starting up the subprocesses
    unless self.write_pidfile("0",:check)
      self.read_pidfile
      return true if @pid # so it's already running, eh.
    end

    # Start the SSH master in a sub-subprocess
    @pid = nil # will inherit value of 'subpid' below
    socket = self.control_path
    File.unlink(socket) rescue true
    pid = Process.fork do
      begin
        (3..50).each { |i| IO.for_fd(i).close rescue true } # with some luck, it's enough
        subpid = Process.fork do
          begin
            Process.setpgrp rescue true
            self.write_pidfile(Process.pid,:force)  # Overwrite : changes the 0 to a real PID
            $stdin.reopen( "/dev/null",    "r") # fd 0
            $stdout.reopen(self.diag_path, "a") # fd 1
            $stdout.sync = true
            $stderr.reopen($stdout)             # fd 2
            File.chmod(0600, self.diag_path) rescue true
            puts "Starting Master #{@key} at #{Time.now.localtime.to_s} as PID #{$$}"
            Kernel.exec(sshcmd)
          ensure
            Kernel.exit!  # should never reach here
          end
        end
        Process.detach(subpid)
      ensure
        Kernel.exit!
      end
    end

    # Wait for it to be fully established (up to CONFIG[:SPAWN_WAIT_TIME] seconds).
    debugTrace("Started SSH master with PID #{pid}...")
    Process.waitpid(pid) # not the PID we want in @pid!
    pidfile = self.pidfile_path
    CONFIG[:SPAWN_WAIT_TIME].times do
      break if File.exist?(socket)         &&
               File.exists?(pidfile)       &&
               File.size(pidfile)      > 0 &&
               self.raw_read_pidfile  != 0  # a zero means not yet fully setup; a nil is an error and no need to wait further
      debugTrace("... waiting for confirmed creation of socket and PID file...")
      sleep 1
    end

    # OK, let's see if it started OK.
    self.read_pidfile
    debugTrace("Master confirmed started.") if @pid
    return true if @pid

    # Something went wrong, kill it if it exists.
    debugTrace("Master did not start.")
    pid = self.raw_read_pidfile
    pid = nil if pid == 0 # zero is the special value when trying to fork
    if pid
      debugTrace("Killing spurious process at PID #{pid}.")
      Process.kill("HUP",pid) rescue true
      sleep 1
      Process.kill("TERM",pid) rescue true
    end

    false
  end

  # Stop the master SSH connection, disabling all tunnels if
  # necessary. This will kill the subprocess used to maintain
  # the master SSH.
  def stop
    self.properly_registered?
    return true  if @nomaster # when not a master, stop means nothing
    return false unless self.read_pidfile

    debugTrace("STOP: #{$$} Killing master for #{@key}.")
    File.open(self.diag_path,"a") { |fh| fh.write("Stopping Master #{@key} at #{Time.now.localtime.to_s}\n") }
    Process.kill("HUP",@pid) rescue true
    sleep 1
    Process.kill("TERM",@pid) rescue true
    @pid = nil
    self.delete_pidfile
    true
  end

  # Returns true if the master SEEMS to be alive;
  # this check is performed by checking that the
  # socket file exists and a process is running,
  # so it's not guaranteed that the other end of
  # the connection is responding.
  def quick_is_alive?
    self.properly_registered?
    return true if @nomaster # when no master actually exists, we assume all's OK.

    socket = self.control_path
    return false unless File.exist?(socket) && File.socket?(socket)
    return false unless self.read_pidfile
    true
  end

  # Check to see if the master SSH connection is alive and well.
  def is_alive?

    return false unless self.quick_is_alive?
    return false if     @pid.blank? && ! @nomaster

    shared_options = self.ssh_shared_options
    sshcmd = "ssh -q -x -n #{shared_options} " +
             "echo OK-#{Process.pid}"

    # Prepare a subprocess that will tell us
    # we waited too long for an answer.
    my_pid      = $$
    signal_name = "SIGURG"
    alarm_pid = Process.fork do
      begin
        Process.setpgrp rescue true
        (3..50).each { |i| IO.for_fd(i).close rescue true } # with some luck, it's enough
        Signal.trap("TERM") do
          debugTrace("Alarm subprocess #{$$} for #{@key}: told to exit with TERM.")
          Kernel.exit!
        end
        Signal.trap("EXIT") do
          debugTrace("Alarm subprocess #{$$} for #{@key}: exiting.")
        end
        debugTrace("Alarm subprocess #{$$} for #{@key}: Waiting at #{Time.now}.")
        Kernel.sleep(CONFIG[:IS_ALIVE_TIMEOUT])
        debugTrace("Alarm subprocess #{$$} for #{@key}: Notifying master of timeout at #{Time.now}.")
        Process.kill(signal_name,my_pid)
      ensure
        Kernel.exit!
      end
    end
    Process.detach(alarm_pid)

    old_handler = Signal.trap(signal_name) do
      debugTrace("Master program for #{@key}: Got timeout notification. Killing master.")
      self.stop rescue true # just give up and kill the SSH master!
    end

    begin
      debugTrace("Master checking is_alive for #{@key} with alarm: #{alarm_pid}")
      okout = ""
      IO.popen(sshcmd,"r") { |fh| okout=fh.read }
      return true if okout.index("OK-#{Process.pid}")
      return false
    rescue
      return false
    ensure
      if alarm_pid
        debugTrace("Master shutting down ALARM subprocess for #{@key}: #{alarm_pid}")
        #Kernel.sleep(2)
        #Process.kill("TERM",alarm_pid) rescue true
        Process.kill("KILL",alarm_pid) rescue true # radically
      end
      if old_handler && signal_name
        Signal.trap(signal_name,old_handler) rescue true # restore it
      end
    end
  end

  # Returns the ssh command's options to connect to
  # the the master control path.
  # By default, we do not return the 'ssh' command
  # itself but we do include the user and hostname.
  # A typical return value would be something like:
  #
  #  "-port 1234 -o ConnectTimeout=10 -o ControlMaster=no -o ControlPath=/tmp/something user@host"
  #
  # which allows you to add more options at the beginning
  # and the end of any ssh command being built. Note that
  # generally, if the master is active, the port, user
  # and host are ignored completely when re-using this
  # string as part of another 'ssh' command.
  def ssh_shared_options(control_master="no")
    socket = self.control_path

    # Base options that are always present
    args_string  = ""
    args_string += " -p #{@port}" if @port != 22
    args_string += " " + ssh_config_options_as_string()

    # When @nomaster is true, it means we're not even building
    # the options for an existing master. The client probably
    # just need this object to issue one-shot commands.
    if ! @nomaster
      args_string += " -o ServerAliveInterval=30"
      args_string += " -o ServerAliveCountMax=5"
      args_string += " -o ControlMaster=#{control_master}"
      args_string += " -o ControlPath=#{socket}"
    end

    # Finally, user and host
    args_string += " #{@user}@#{@host} "

    args_string
  end

  # Runs the specified +shell_command+ (a bash command) on
  # the remote end of the SSH connection. When given a block,
  # the block will receive a writable filehandle that can be
  # used to send data to the remote command.
  #
  # The +options+ hash can be used to provide local filenames
  # for :stdin, :stdout and :stderr. Note that :stdin is ignored
  # if a block is provided.
  # Appending to output files can be enabled by giving a true value
  # to the options :stdout_append and :stderr_append.
  def remote_shell_command_writer(shell_command, options={}, &block)
    pipe_for_remote_shell_command(shell_command, 'w', options, &block)
  end

  # Runs the specified +shell_command+ (a bash command) on
  # the remote end of the SSH connection. When given a block,
  # the block will receive a readable filehandle that can be
  # used to read data from the remote command.
  #
  # The +options+ hash can be used to provide local filenames
  # for :stdin, :stdout and :stderr. Note that :stdout is ignored
  # if a block is provided.
  # Appending to output files can be enabled by giving a true value
  # to the options :stdout_append and :stderr_append.
  def remote_shell_command_reader(shell_command, options={}, &block)
    pipe_for_remote_shell_command(shell_command, 'r', options, &block)
  end

  # Runs the specified +shell_command+ (a bash command) on
  # the remote end of the SSH connection. When given a block,
  # the block will receive a readable or writable filehandle
  # that can be used to read/write data from/to the remote command.
  #
  # The +direction+ parameter needs to be set to 'r' for read and
  # 'w' for write.
  #
  # The +options+ hash can be used to provide local filenames
  # for :stdin, :stdout and :stderr. Note that :stdout is ignored
  # if a block is provided with a 'r' +direction+, and similarly
  # :stdin is ignored if a block is provided in a 'w' +direction+.
  # Appending to output files can be enabled by giving a true value
  # to the options :stdout_append and :stderr_append.
  def pipe_for_remote_shell_command(shell_command, direction, options={})

    shared_opts = self.ssh_shared_options
    command     = shell_escape(shell_command)
    stdin       = bash_redirection(options,0,"<",:stdin)
    stdout      = bash_redirection(options,1,">",:stdout)
    stderr      = bash_redirection(options,2,">",:stderr)

    no_stdin       = options[:stdin] == '/dev/null'       ? "-n" : ""
    use_pseudo_tty = options[:force_pseudo_ttys].present? ? "-t" : ""

    ssh_command  = "ssh -q -x #{no_stdin} #{use_pseudo_tty} #{shared_opts} #{command} #{stderr}"
    ssh_command += " #{stdin}"  if direction == 'r' # with or without block
    ssh_command += " #{stdout}" if direction == 'w' # with or without block

    if block_given? then
      debugTrace("IO.popen() with command: #{ssh_command}")
      IO.popen(ssh_command, direction) { |io| yield(io) }
    else
      ssh_command += " #{stdout}" if direction == 'r' # the 'other' direction
      ssh_command += " #{stdin}"  if direction == 'w' # the 'other' direction
      debugTrace("system() with command: #{ssh_command}")
      system(ssh_command)
    end
  end

  # This stops the master SSH connection if it is alive, and
  # de-register the object from the class. It's nice but not
  # really necessary.
  def destroy
    self.stop
    ssh_masters = self.ssh_master_cache
    ssh_masters.delete @key
    true
  end

  protected

  # Returns the path to the SSH ControlPath socket.
  def control_path #:nodoc:
    simple_base = "mstr.#{@simple_key}"
    simple_base = "#{simple_base}_#{@uniq}" if @uniq
    base      = simple_base
    base      = "#{@category}/#{simple_base}" if @category
    sock_dir  = "#{CONFIG[:CONTROL_SOCKET_DIR_1]}"
    sock_path = "#{sock_dir}/#{base}" # preferred location
    if sock_path.size >= CONFIG[:CONTROL_SOCKET_MAX_LENGTH] || ! File.directory?(sock_dir) # limitation in control path length in ssh
      sock_dir  = "#{CONFIG[:CONTROL_SOCKET_DIR_2]}"
      sock_path = "#{sock_dir}/#{base}" # alternative, hopefully shorter than 80 chars long!
    end
    if sock_path.size >= CONFIG[:CONTROL_SOCKET_MAX_LENGTH] # still too long?!?
      base      = Digest::MD5.hexdigest(base) # the "@category/" goes into the hash too
      sock_dir  = "/tmp"
      sock_path = "#{sock_dir}/#{base}" # flat, no longer a category subdir
      ultra_short_workaround = true
    end
    if @category && ! ultra_short_workaround # this method is turning into a type of pasta
      cat_dir = "#{sock_dir}/#{@category}"
      unless File.directory?(cat_dir)
        begin
          Dir.mkdir(cat_dir,0700) # prepare subdir for category
        rescue Errno::EEXIST
          raise unless File.directory?(cat_dir)
          # all OK, seems we got a race condition
        end
      end
    end
    sock_path
  end

  def pidfile_path #:nodoc:
    base = self.control_path.sub(/.*\//,"") + ".pid"
    dir  = @category.presence ? "#{CONFIG[:PID_DIR]}/#{@category}" : CONFIG[:PID_DIR]
    begin
      Dir.mkdir(dir,0700) if ! File.directory?(dir)
    rescue Errno::EEXIST
      raise unless File.directory?(dir)
      # all OK, seems we got a race condition
    end
    "#{dir}/#{base}"
  end

  def diag_path #:nodoc:
    return "/dev/null" if @no_diag
    self.pidfile_path.sub(/\.pid\z/,".oer")
  end

  def write_pidfile(pid,action) #:nodoc:
    pidfile = self.pidfile_path
    if action == :force
      File.open(pidfile,"w") { |fh| fh.write(pid.to_s) }
      File.chmod(0600, pidfile) rescue true
      return true
    end
    # Action is :check, it means we must fail if the file exists
    return false if File.exist?(pidfile)
    begin
      fd = IO.sysopen(pidfile, Fcntl::O_WRONLY | Fcntl::O_EXCL | Fcntl::O_CREAT)
      f = IO.open(fd)
      f.syswrite(pid.to_s)
      f.close
      File.chmod(0600, pidfile) rescue true
      return true
    rescue Errno::EEXIST
      return false
    end
  end

  # Returns @pid if the PID file contains
  # a legal PID number for a currently running SSH
  # master. If necessary, sets @pid with the PID
  # before returning it. Otherwise, makes sure
  # @pid is reset to nil. This method makes several
  # checks, too: the socket must exist, the pidfile
  # must exist.
  def read_pidfile(options = {}) #:nodoc:
    socket  = self.control_path
    pidfile = self.pidfile_path
    unless File.exist?(socket) && File.exist?(pidfile)
      self.delete_pidfile
      @pid = nil
      return nil
    end
    @pid = self.raw_read_pidfile # can be nil if it's incorrect
    @pid = nil if @pid == 0
    @pid
  end

  # Just reads the pidfile and returns the numeric
  # pid found there. Returns nil if it seems incorrect.
  def raw_read_pidfile #:nodoc:
    begin
      pidfile = self.pidfile_path
      line = nil
      File.open(pidfile,"r") { |fh| line = fh.read }
      return nil unless line && line.match(/\A\d+/)
      pid = line.to_i
      return pid if pid == 0 # when we're still in the process of forking
      pid = nil unless self.process_ok?(pid)
      return pid
    rescue
      return nil
    end
  end

  # Makes sure that a process owned by us runs for this pid.
  def process_ok?(mypid) #:nodoc:
    return false unless mypid
    process_info = Sys::ProcTable.ps(:pid => mypid.to_i)
    return false unless process_info
    procuid   = process_info.ruid rescue nil
    procuid ||= process_info.uid rescue nil
    return true if procuid && (Process.uid == procuid || Process.euid == procuid)
    false
  end

  def delete_pidfile #:nodoc:
    File.unlink(self.pidfile_path) rescue true
  end

  # Checks that the current instance is the one registered
  def properly_registered? #:nodoc:
    found = self.class.find(@user,@host,@port, :category => @category, :uniq => @uniq )
    raise "This SSH master is no longer registered with the class." unless found
    raise "This SSH master object does not match the object registered in the class!" if
      found.object_id != self.object_id
    true
  end

  private

  # Returns as a single string the set of configurable ssh options
  # e.g. "-o BatchMode=yes -o Something=SomeValue"; by default
  # the options are defined in DEFAULT_SSH_CONFIG_OPTIONS
  # If a value is nil, the options will not be inserted at all in the
  # string.
  def ssh_config_options_as_string #:nodoc:
    @ssh_config_options
      .reject { |var,value| value.nil? }
      .map    { |var,value| "-o #{shell_escape(var)}=#{shell_escape(value)}" }
      .join(" ")
  end

  # This utility method escapes properly any string such that
  # it becomes a literal in a bash command; the string returned
  # will include the surrounding single quotes.
  #
  #   shell_escape("Mike O'Connor")
  #
  # returns
  #
  #   'Mike O'\''Connor'
  def shell_escape(s) #:nodoc:
    "'" + s.to_s.gsub(/'/,"'\\\\''") + "'"
  end

  # Create a bash redirection operator (like "<infile"
  # or "2>>err.txt"); +options+ is a hash containing the +key+
  # whose value is the file to use for redirection; +fd+
  # is the number of the file descriptor; +redir_op+ is one
  # of '<' or '>'. If the +options+ also contain a true
  # value for a key symbol named ":{key}_append", then
  # output redirection will be done in append mode (>>).
  def bash_redirection(options,fd,redir_op,key) #:nodoc:
    file          = options[key]
    return "" unless file # no redirection
    do_append_key = (key.to_s + "_append").to_sym
    append_op     = redir_op
    append_op    += redir_op if options[do_append_key] && redir_op == '>'
    "#{fd}#{append_op}#{shell_escape(file)}"
  end

  def debugTrace(message) #:nodoc:
    return unless @debug
    STDERR.puts("\e[1;33m#{message}\e[0m")
  end

end

