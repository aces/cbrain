
#
# CBRAIN Project
#
# This class provides the functionality necessary to create,
# destroy and manage SSH tunnels to other hosts.
#
# Original author: Pierre Rioux
#
# $Id$
#

require 'fcntl'

# = SSH Tunnel Utility Class 
#
# This class provides the functionality necessary to create,
# destroy, and manage persistent SSH tunnels to other hosts.
# Tunnels are tied to a master, persistent SSH process running in
# a subprocess; the master SSH process is controled using the
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
#    master = SshTunnel.new('john','my.example.com',22)
#    master.add_tunnel(:forward,1234,'localhost',8080)
#    master.start
#    # Now we can connect to port 1234 locally and see the web server.
#    # Later on, even if we have lost the variable 'master'
#    # above, we can find it again to kill the tunnel:
#    master = SshTunnel.find('john','my.example.com',22)
#    master.stop
#
# The master SSH process uses connection sharing to improve
# connection latency; this is accomplished by allocating UNIX
# domain sockets in /tmp; see also the ControlMaster and
# ControlPath options in SSH's manual (in particular, for
# the man page ssh_config, and for the '-o' option of 'ssh').
class SshTunnel

  Revision_info="$Id$"
  # Kernel.at_exit { SshTunnel.destroy_all } # BAD when multiple instances!

  # This class method allows you to find out and fetch the
  # instance object that represents a master tunnel to a
  # remote host (there can only be a single tunnel for
  # each triplet [user,host,port] so we might as well remember
  # the objects in the class).
  def self.find(remote_user,remote_host,remote_port=22)
    remote_port ||= 22
    @@ssh_tunnels ||= {}
    key = "#{remote_user}@#{remote_host}:#{remote_port}"
    @@ssh_tunnels[key]
  end

  # This method is like find() except that it will create
  # the necessary control object if necessary.
  def self.find_or_create(remote_user,remote_host,remote_port=22)
    remote_port ||= 22
    tunnelobj = self.find(remote_user,remote_host,remote_port) ||
                self.new( remote_user,remote_host,remote_port)
    tunnelobj
  end

  # Works like find, but expect a single key
  # in a format like "user@host:port".
  def self.find_by_key(key)
    @@ssh_tunnels[key]
  end

  # Returns all the configured SSH connections (not all
  # of them may be alive).
  def self.all
    @@ssh_tunnels.values
  end

  # Returns an array containing all the keys for the currently
  # configued master SSH connections (not all of them
  # may be alive). Keys are strings like "user@host:port".
  def self.all_keys
    @@ssh_tunnels.keys
  end

  def self.destroy_all #:nodoc:
    @@ssh_tunnels ||= {}
    @@ssh_tunnels.values.each { |tun| tun.destroy }
  end

  # Create a control object for a potential tunnel to
  # host +host+, as user +user+ with SSH port +port+.
  # The tunnel is not started. The object is registered
  # in the class and can be found later using the
  # find() class method. This means that projects using
  # this library do not have to save the control object
  # anywhere.
  def initialize(remote_user,remote_host,remote_port=22)

    remote_port ||= 22
    if remote_port && remote_port.is_a?(String)
      if remote_port =~ /^\s*$/
        remote_port = 22 
      else
        remote_port = remote_port.to_i
      end
    end

    raise "SSH tunnel's \"user\" is not a simple identifier." unless
      remote_user =~ /^[a-zA-Z0-9][a-zA-Z0-9\-\.]*$/
    raise "SSH tunnel's \"host\" is not a simple host name." unless
      remote_host =~ /^[a-zA-Z0-9][a-zA-Z0-9\-\.]*$/
    raise "SSH tunnel's \"port\" is not a port number." unless
      remote_port.is_a?(Fixnum) && remote_port > 0 && remote_port < 65535

    @user = remote_user
    @host = remote_host
    @port = remote_port

    raise "This tunnel spec is already registered with the class." if
      self.class.find(@user,@host,@port)

    @pid             = nil
    @forward_tunnels = []   # [ 1234, "some.host", 4566 ]
    @reverse_tunnels = []   # [ 1234, "some.host", 4566 ]

    # Register it
    @key = "#{@user}@#{@host}:#{@port}"
    @@ssh_tunnels[@key] = self

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
  def add_tunnel(direction, accept_port, dest_host, dest_port)

    self.properly_registered?

    raise "'direction' must be :forward or :reverse." unless
      direction == :forward || direction == :reverse
    raise "'accept_port' must be a port number > 1024." unless
      accept_port.is_a?(Fixnum) && accept_port > 1024 && accept_port < 65535
    raise "'dest_port' must be a port number." unless
      dest_port.is_a?(Fixnum) && dest_port > 0 && dest_port < 65535
    raise "'dest_host' is not a simple host name." unless
      dest_host =~ /^[a-zA-Z0-9][a-zA-Z0-9\-\.]*$/

    tunnel_spec = [ accept_port, dest_host, dest_port ]
    if direction == :forward
      if @forward_tunnels.find { |spec| spec[0] == accept_port }
        raise "Error: there's already a forward tunnel configured for port #{accept_port}."
      end
      @forward_tunnels << tunnel_spec
    else
      if @reverse_tunnels.find { |spec| spec[0] == accept_port }
        raise "Error: there's already a reverse tunnel configured for port #{accept_port}."
      end
      @reverse_tunnels << tunnel_spec
    end
    true
  end

  # Get the list of currently configured tunnels (note that they
  # may not be active; only tunnels present at the moment that
  # start() was called will be active). The returned value is
  # an array of triplets like this:
  #    [ accept_port, dest_host, dest_port ]
  def get_tunnels(direction)
    raise "'direction' must be :forward or :reverse." unless
      direction == :forward || direction == :reverse
    return direction == :forward ? @forward_tunnels : @reverse_tunnels
  end

  # This is like get_tunnels, except the returned array
  # contains strings where the tree components are separated by
  # colons, such as "1234:myhost:5678", where 1234 is always
  # the +accept_port+ specified during add_tunnel().
  def get_tunnels_strings(direction)
    tunnels = self.get_tunnels(direction)
    tunnels.map { |s| s.join(":") }
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
  
  # Start the master SSH connection, including all tunnels if
  # necessary. The connection is maintained in a subprocess.
  # If a subprocess is already running, nothing will happen:
  # you have to stop() if before you can restart it.
  def start(label = nil)

    self.properly_registered?
    return true if self.read_pidfile

    sshcmd = "ssh -n -N -x -M "

    if ! label.blank? && label.to_s =~ /^\w+$/
      sshcmd += "-o SendEnv=#{label.to_s} "
    end

    self.get_tunnels_strings(:forward).each { |spec| sshcmd += " -L #{spec}" }
    self.get_tunnels_strings(:reverse).each { |spec| sshcmd += " -R #{spec}" }

    shared_options = self.ssh_shared_options("yes") # ControlMaster=yes
    sshcmd += " #{shared_options}"

    unless self.write_pidfile("0",:check) # 0 means in the process of starting up subprocess
      self.read_pidfile
      return true if @pid # so it's already running, eh.
    end


    # Start the SSH master in a sub-subprocess
    @pid = nil # will inherit value of 'subpid' below
    socket = self.control_path
    File.unlink(socket) rescue true
    pid = Process.fork do
      (3..50).each { |i| IO.for_fd(i).close rescue true } # with some luck, it's enough
      subpid = Process.fork do
        self.write_pidfile($$,:force)  # Overwrite
        Kernel.exec(sshcmd) # TODO: intercept output for diagnostics?
        Kernel.exit!  # should never reach here
      end
      Process.detach(subpid)
      Kernel.exit!
    end

    # Wait for it to be fully established (up to 10 seconds).
    Process.waitpid(pid) # not the PID we want in @pid!
    pidfile = self.pidfile_path
    10.times do
      break if File.exist?(socket) && File.exist?(pidfile)
      sleep 1
    end
    self.read_pidfile

    return @pid.blank? ? false : true
  end

  # Stop the master SSH connection, disabling all tunnels if
  # necessary. This will kill the subprocess used to maintain
  # the master SSH.
  def stop
    self.properly_registered?
    return false unless self.read_pidfile

    Process.kill("TERM",@pid) rescue true
    @pid = nil
    self.delete_pidfile
    true
  end

  # Check to see if the master SSH connection is alive and well.
  def is_alive?

    self.properly_registered?

    socket = self.control_path
    return false unless File.exist?(socket)
    return false unless self.read_pidfile
    
    shared_options = self.ssh_shared_options
    sshcmd = "ssh -x -n #{shared_options} " +
             "echo OK-#{$$}"

    begin
      okout = ""
      IO.popen(sshcmd,"r") { |fh| okout=fh.read }
      return true if okout =~ /OK-#{$$}/
      return false
    rescue
      return false
    end
  end

  # Returns the ssh command's options to connect to
  # the tunnel using the master control path.
  # By default, we do not return the 'ssh' command
  # itself but we do include the user and hostname.
  # A typical return value would be something like:
  #
  #  "-port 1234 -o ConnectTimeout=10 -o ControlMaster=no -o ControlPath=/tmp/something user@host"
  #
  # which allows you to add more options at the beginning
  # and the end of any ssh command being built. Note that
  # generally, if the master is active, the port, user
  # and host are ignored completely.
  def ssh_shared_options(control_master="no")
    socket = self.control_path
    " -p #{@port}"                        +
    " -o ConnectTimeout=10"               +
    " -o StrictHostKeyChecking=false"     +
    " -o PasswordAuthentication=false"    +
    " -o KbdInteractiveAuthentication=no" +
    " -o KbdInteractiveDevices=false"     +
    " -o ServerAliveInterval=180"         +
    " -o ServerAliveCountMax=5"           +
    " -o ControlMaster=#{control_master}" +
    " -o ControlPath=#{socket}"           +
    " #{@user}@#{@host} "
  end

  # This stops the master SSH connection if it is alive, and
  # de-register the object from the class. It's nice but not
  # really necessary.
  def destroy
    self.stop
    key = "#{@user}@#{@host}:#{@port}"
    @@ssh_tunnels.delete key
    true
  end

  protected

  # Returns the path to the SSH ControlPath socket.
  def control_path #:nodoc:
    "/tmp/ssh_master.#{@user}@#{@host}:#{@port}"
  end

  def pidfile_path #:nodoc:
    self.control_path + ".pid"
  end

  def write_pidfile(pid,action) #:nodoc:
    pidfile = self.pidfile_path
    if action == :force
      File.open(pidfile,"w") { |fh| fh.write(pid.to_s) }
      return true
    end
    # Action is :check, it means we must fail if the file exists
    return false if File.exist?(pidfile)
    begin
      fd = IO::sysopen(pidfile, Fcntl::O_WRONLY | Fcntl::O_EXCL | Fcntl::O_CREAT)
      f = IO.open(fd)
      f.syswrite(pid.to_s)
      f.close
      return true
    rescue
      return false
    end
  end

  # Returns @pid if the PID file contains
  # a legal PID number for a currently running SSH
  # master. If necessary, sets @pid with the PID
  # before returning it. Otherwise, makes sure
  # @pid is reset to nil.
  def read_pidfile #:nodoc:
    socket  = self.control_path
    pidfile = self.pidfile_path
    unless File.exist?(socket) && File.exist?(pidfile)
      self.delete_pidfile
      @pid = nil
      return nil
    end
    return @pid if @pid
    begin
      line = nil
      File.open(pidfile,"r") { |fh| line = fh.read }
      return nil unless line && line.match(/^\d+/)
      @pid = line.to_i
      @pid = nil if @pid == 0 # leftover from :check mode of write_pidfile() ? Crash?
      return @pid
    rescue
      return nil
    end
  end

  def delete_pidfile #:nodoc:
    File.unlink(self.pidfile_path) rescue true
  end

  # Checks that the current instance is the one registered
  def properly_registered? #:nodoc:
    found = self.class.find(@user,@host,@port)
    raise "This tunnel is no longer registered with the class." unless found
    raise "This tunnel object does not match the object registered in the class!" if
      found.object_id != self.object_id
    true
  end
  
end
