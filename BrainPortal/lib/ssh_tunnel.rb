
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
#    master.add_tunnel(1234,'localhost',8080)
#    master.start
#    # Now we can connect to port 1234 locally and see the web server.
#    # Later on, even if we have lost the variable 'master'
#    # above, we can find it again to kill the tunnel:
#    master = SshTunnel.find('john','my.example.com',22)
#    master.stop
#
class SshTunnel

  Revision_info="$Id$"

  # This class method allows you to find out and fetch the
  # instance object that represents a master tunnel to a
  # remote host (there can only be a single tunnel for
  # each triplet [user,host,port] so we might as well remember
  # the objects in the class).
  def self.find(remote_user,remote_host,remote_port=22)
    @@ssh_tunnels ||= {}
    key = "#{remote_user}@#{remote_host}:#{remote_port}"
    @@ssh_tunnels[key]
  end

  # This method is like find() except that it will create
  # the necessary control object if necessary.
  def self.find_or_create(remote_user,remote_host,remote_port=22)
    tunnelobj = self.find(remote_user,remote_host,remote_port) ||
                self.new( remote_user,remote_host,remote_port)
    tunnelobj
  end

  # Returns an array containing all the currently
  # configued master SSH connections (not all of them
  # may be alive). Values are strings like "user@host:port".
  def self.all_connection_keys
    @@ssh_tunnels.keys
  end

  # Create a control object for a potential tunnel to
  # host +host+, as user +user+ with SSH port +port+.
  # The tunnel is not started. The object is registered
  # in the class and can be found later using the
  # find() class method. This means that projects using
  # this library do not have to save the control object
  # anywhere.
  def initialize(remote_user,remote_host,remote_port=22)

    raise "SSH tunnel's \"user\" is not a simple identifier." unless
      remote_user =~ /^[a-zA-Z0-9][a-zA-Z0-9\-\.]*$/
    raise "SSH tunnel's \"host\" is not a simple host name." unless
      remote_host =~ /^[a-zA-Z0-9][a-zA-Z0-9\-\.]*$/
    raise "SSH tunnel's \"port\" is not a port number." unless
      remote_port.is_a?(Fixnum) && remote_port > 0 && remote_port < 65535

    @user = remote_user
    @host = remote_host
    @port = remote_port

    @pid  = nil
    @forward_tunnels = []   # "1234:some.host:4566"
    @reverse_tunnels = []   # "1234:some.host:4566"

    raise "This tunnel spec is already registered with the class." if
      self.class.find(@user,@host,@port)
    key = "#{@user}@#{@host}:#{@port}"
    @@ssh_tunnels[key] = self
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

    tunnel_spec = "#{accept_port}:#{dest_host}:#{dest_port}"
    if direction == :forward
      @forward_tunnels << tunnel_spec
    else
      @reverse_tunnels << tunnel_spec
    end
    true
  end

  # Get the list of currently configured tunnels (note that they
  # may not be active; only tunnels present at the moment that
  # start() was called will be active). The returned value is
  # an array of strings with the three components joined with
  # colons, such as "1234:myhost:5678", where 1234 is always
  # the +accept_port+ specified during add_tunnel().
  def get_tunnels(direction)
    raise "'direction' must be :forward or :reverse." unless
      direction == :forward || direction == :reverse
    return direction == :forward ? @forward_tunnels : @reverse_tunnels
  end

  # This is like get_tunnels, except the returned array
  # contains triplets in array form:
  #    [ accept_port, dest_host, dest_port ]
  def get_tunnels_parsed(direction)
    tunnels = self.get_tunnels(direction)
    tunnels.map { |s| s.split(/:/) }
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
  def start

    self.properly_registered?

    self.stop if @pid
    socket = self.controlpath
    sshcmd = "ssh -n -N -x -p #{@port}"            +
             " -o ConnectTimeout=10"               +

             " -o StrictHostKeyChecking=false"     +
             " -o PasswordAuthentication=false"    +
             " -o KbdInteractiveAuthentication=no" +
             " -o KbdInteractiveDevices=false"     +

             " -M"                                 +
             " -o ControlMaster=yes"               +
             " -o ControlPath=#{socket}"

    @forward_tunnels.each { |spec| sshcmd += " -L #{spec}" }
    @reverse_tunnels.each { |spec| sshcmd += " -R #{spec}" }

    sshcmd += " #{@user}@#{@host}"

    @pid = Process.fork do
      File.unlink(socket) rescue true
      Kernel.exec(sshcmd) # TODO: intercept output for diagnostics?
      Kernel.exit!  # should never reach here
    end

    #Process.detach(@pid) # NOT detach, that way tunnel is killed if ruby is killed
    @pid
  end

  # Stop the master SSH connection, disabling all tunnels if
  # necessary. This will kill the subprocess used to maintain
  # the master SSH.
  def stop
    return false unless @pid

    self.properly_registered?

    socket = self.controlpath
    Process.kill("TERM",@pid) rescue true
    #sleep 1
    #if File.exist?(socket)
    #  Process.kill("KILL",@pid)
    #end
    @pid = nil
    true
  end

  # Check to see if the master SSH connection is alive and well.
  def is_alive?

    self.properly_registered?

    return false unless @pid
    
    socket = self.controlpath
    return false unless File.exist?(socket)

    sshcmd = "ssh -n -x -p #{@port}"     +
             " -o ConnectTimeout=10"     +
             " -o ControlMaster=no"      +
             " -o ControlPath=#{socket}" +
             " #{@user}@#{@host} "       +
             "echo OK-#{$$}"

    okout = ""
    begin
      IO.popen(sshcmd,"r") { |fh| okout=fh.read }
      return true if okout =~ /OK-#{$$}/
      return false
    rescue
      return false
    end
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
  def controlpath #:nodoc:
    "/tmp/ssh_master.#{@user}@#{@host}:#{@port}.socket"
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
