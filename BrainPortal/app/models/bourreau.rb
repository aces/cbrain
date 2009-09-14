
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

  # Checks if this Bourreau is available or not.
  def is_alive?
    info = self.update_info
    return false if info.name == "???"
    true
  rescue
    false
  end

  # Returns this Bourreau's URL. This URL is adjusted
  # depending on whether or not the ActiveResource
  # connection is tunneled through a SSH master connection.
  # In the case of a tunnel, the connection is established
  # to host localhost, on a port number equal to (3090 +
  # the ID of the Bourreau).
  def site
    host = actres_host
    port = actres_port
    dir  = actres_dir || ""
    if self.has_ssh_control_info? && self.tunnel_actres_port
      host = "localhost"
      port = 3090+self.id  # see also in start_tunnels()
    end
    "http://" + host + (port && port > 0 ? ":#{port}" : "") + dir
  end

  # Returns (and creates if necessary) the master SSH connection
  # for this Bourreau. The method does not start it, it it's created.
  def ssh_master
    master = SshTunnel.find_or_create(self.ssh_control_user,self.ssh_control_host,self.ssh_control_port || 22)
    master
  end

  # This sets up and starts a SSH master connection to the host
  # on which the Bourreau is running, and optionally configures
  # any or both of two supplemental tunnels: a forward tunnel to
  # carry the DrmaaTask ActiveResource connections, and a reverse
  # tunnel to carry the ActiveRecord DB connection. The
  # tunnels are set up if the following attributes
  # are set:
  #
  # *tunnel_mysql_port*:: Optional; must be an unused port number on the Bourreau
  #                       side where it will expect to connect to the DB server. Setting
  #                       a value to this attribute means that the remote database.yml
  #                       file will get rewritten automatically.
  # *tunnel_actres_port*:: Optional; must be an unused port number on the Bourreau
  #                        side that it will open as its HTTP acceptor (it will become
  #                        the argument to the "-p" option for its "script/server").
  #                        The local BrainPortal will tunnel its requests to it
  #                        using a local port number of (3090 + the ID of the Bourreau).
  def start_tunnels
    
    return false unless self.has_ssh_control_info?

    # Setup SSH master connection
    master = self.ssh_master
    return true if master.is_alive?  # we don't reconfigure if already alive

    master.delete_tunnels(:forward)
    master.delete_tunnels(:reverse)

    # Setup DB tunnel
    if self.has_db_tunneling_info?
      remote_db_port  = self.tunnel_mysql_port
      myconfigs       = ActiveRecord::Base.configurations
      myrailsenv      = ENV["RAILS_ENV"] || "production"
      myconfig        = myconfigs[myrailsenv]
      local_db_host   = myconfig["host"]  || "localhost"
      local_db_port   = (myconfig["port"] || "3306").to_i
      master.add_tunnel(:reverse, remote_db_port, local_db_host, local_db_port)
    end

    # Setup ActiveResource tunnel
    if self.has_actres_tunneling_info?
      local_port  = 3090+self.id # see also in site()
      remote_port = self.tunnel_actres_port
      master.add_tunnel(:forward, local_port, "localhost", remote_port)
    end

    # If the SSH master and tunnels have already been started by
    # another instance, the following will simply do nothing.
    return false unless master.start
    true
  end

  # This stops the master SSH connection to the remote Bourreau,
  # including any present tunnels. This can seriously affect
  # the remote bourreau if DB tunneling is in effect, as it
  # will kill its DB connection! Otherwise, the remote
  # Bourreau is not affected.
  def stop_tunnels
    return false unless self.has_ssh_control_info?
    master = self.ssh_master
    master.stop if master
    true
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

    return false unless self.has_remote_control_info?
    bourreau_rails_home = self.ssh_control_rails_dir

    self.start_tunnels

    # If we tunnel the DB, we get a non-blank yml file here
    yml  = self.has_db_tunneling_info?     ? self.build_db_yml_for_tunnel : ""

    # What port the Rails Bourreau will listen to?
    port = self.has_actres_tunneling_info? ? self.tunnel_actres_port : self.actres_port

    # What environment will it run under?
    myrailsenv = ENV["RAILS_ENV"] || "production"

    # SSH command to start it up; we pipe to it either a new database.yml file
    # which will be installed, or "" which means to use whatever
    # yml file is already configured at the other end.
    captfile    = "/tmp/start.out.#{$$}"
    ssh_options = self.ssh_master.ssh_shared_options
    startcmd    = "ruby #{bourreau_rails_home}/script/cbrain_remote_ctl " +
                  "start -e #{myrailsenv} -p #{port}"
    dash_n      = yml.blank? ? "-n" : ""
    sshcmd = "ssh -x #{dash_n} #{ssh_options} #{startcmd} >'#{captfile}' 2>&1"
    IO.popen(sshcmd,"w") { |pipe| pipe.write(yml) }
    out = File.read(captfile) rescue ""
    File.unlink(captfile) rescue true
    return true if out =~ /Bourreau Started/i # output of 'cbrain_remote_ctl'
    false
  end

  # Stop a Bourreau remotely. The requirements for this to work are
  # the same as with start().
  def stop

    return false unless self.has_remote_control_info?
    bourreau_rails_home = self.ssh_control_rails_dir

    self.start_tunnels  # tunnels must be STARTed in order to STOP the Bourreau!

    # SSH command to start it up
    ssh_options = self.ssh_master.ssh_shared_options
    stopcmd = "ruby #{bourreau_rails_home}/script/cbrain_remote_ctl stop"
    sshcmd  = "ssh -n -x #{ssh_options} #{stopcmd}"
    confirm = ""
    IO.popen(sshcmd,"r") { |pipe| confirm = pipe.read }
    return true if confirm =~ /Bourreau Stopped/i # output of 'cbrain_remote_ctl'
    false
  end

  # Check that the Bourreau has enough info configured
  # to establish as SSH master connection to it.
  def has_ssh_control_info?
    return true if
      ( ! self.ssh_control_user.blank? ) &&
      ( ! self.ssh_control_host.blank? )
    false
  end

  # Check that the Bourreau has enough info configured
  # to establish as SSH master connection to it and
  # control the remote Bourreau rails application.
  def has_remote_control_info?
     return true if
       (   self.has_ssh_control_info?        ) &&
       ( ! self.ssh_control_rails_dir.blank? )
     false
  end

  # Returns true if this bourreau is configued
  # for DB tunneling
  def has_db_tunneling_info? #:nodoc:
    return true if self.has_ssh_control_info? && ( ! self.tunnel_mysql_port.blank? )
    false
  end

  # Returns true if this bourreau is configued
  # for ActiveResource tunneling
  def has_actres_tunneling_info? #:nodoc:
    return true if self.has_ssh_control_info? && ( ! self.tunnel_actres_port.blank? )
    false
  end

  ###############################################################
  # BourreauInfo methods
  ###############################################################

  class BourreauInfo < ActiveResource::Base
  end

  # Connects to the Bourreau's information channel and
  # get a record of run-time information. It is usually
  # better to call the info method instead, which will
  # cache the result if necessary.
  def update_info
    begin
      BourreauInfo.site    = self.site
      BourreauInfo.timeout = 10
      infos = BourreauInfo.find(:all)
      @info = infos[0] if infos[0]
    rescue
    end
    @info ||= BourreauInfo.new(
      :name               => "???",
      :id                 => 0,
      :host_uptime        => "???",
      :bourreau_cms       => "???",
      :bourreau_cms_rev   => Object.revision_info,  # means 'unknown'
      :bourreau_uptime    => "???",
      :tasks_max          => "???",
      :tasks_tot          => "???",
      :ssh_public_key     => "???",

      # Svn info
      :revision           => "???",
      :lc_author          => "???",
      :lc_rev             => "???",
      :lc_date            => "???",

      :dummy              => "hello"
    )
    @info
  end

  # Returns and cache a record of run-time information about the Bourreau.
  # This method automatically calls update_info if the information has
  # not been cached yet.
  def info
    @info ||= self.update_info
    @info
  end

  protected

  def build_db_yml_for_tunnel #:nodoc:
    myconfigs  = ActiveRecord::Base.configurations
    myrailsenv = ENV["RAILS_ENV"] || "production"
    myconfig   = myconfigs[myrailsenv].dup

    myconfig["host"]   = "127.0.0.1"
    myconfig["port"]   = self.tunnel_mysql_port
    myconfig.delete("socket")

    yml = "# File created automatically on Portal Side\n" +
          "# by " + self.revision_info.svn_id_pretty_file_rev_author_date + "\n\n" +
          "#{myrailsenv}:\n"
    myconfig.each do |field,val|
       yml += "  #{field}: #{val.to_s}\n"
    end
    yml += "\n"
   
    yml
  end

end
