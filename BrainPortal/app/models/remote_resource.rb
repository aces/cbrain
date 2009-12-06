
#
# CBRAIN Project
#
# Original author: Pierre Rioux
#
# $Id$
#

require 'socket'

#Model representing a remote resource, which is always a
#Rails applications with a 'control' controller. Typically,
#the remote Rails application is a Bourreau or a BrainPortal,
#or the current Rails application running locally.
#
#=Attributes:
#[*name*] A string representing a the name of the remote resource.
#[*remote_user*] A string representing a user name to use to access the remote site.
#[*remote_host*] A string representing a the hostname of the remote resource.
#[*remote_port*] An integer representing the port number of the remote resource.
#[*remote_dir*] An string representing the directory of the remote resource.
#[*online*] A boolean value set to whether or not the resource is online.
#[*read_only*] A boolean value set to whether or not the resource is read only.
#[*description*] Text with a description of the remote resource.
#
#= Associations:
#*Belongs* *to*:
#* User
#* Group
class RemoteResource < ActiveRecord::Base

  Revision_info="$Id$"

  validates_uniqueness_of :name
  validates_presence_of   :name, :user_id, :group_id
  validates_format_of     :name, :with  => /^[a-zA-Z0-9][\w\-\=\.\+]*$/,
                                 :message  => 'only the following characters are valid: alphanumeric characters, _, -, =, +, ., ?, !',
                                 :allow_blank => true

  belongs_to  :user
  belongs_to  :group
  has_many    :sync_status



  ############################################################################
  # Access Control Methods
  ############################################################################

  # Returns the RemoteResource object representing
  # the current Rails application.
  def self.current_resource
    #@@current_resource ||= self.find(CBRAIN::SelfRemoteResourceId)
    self.find(CBRAIN::SelfRemoteResourceId)
  end

  # Returns the site associated with the owner of this
  # remote resource.
  def site_affiliation
    @site_affiliation ||= self.user.site
  end

  #Returns whether or not this resource can be accessed by +user+.
  def can_be_accessed_by?(user)
      return true if self.user_id == user.id || user.has_role?(:admin)
      return true if user.has_role?(:site_manager) && self.user.site_id == user.site_id
      user.group_ids.include?(group_id)
  end
  
  #Returns whether or not +user+ has owner access to this
  #remote resource.
  def has_owner_access?(user)
    if user.has_role? :admin
      return true
    end
    if user.has_role?(:site_manager) && self.user.site_id == user.site_id && self.group.site_id == user.site_id
      return true
    end
    if user.id == self.user_id
      return true
    end
    
    false
  end
  
  #Find remote resource identified by +id+ accessible by +user+.
  #
  #*Accessible* remote resources  are:
  #[For *admin* users:] any remote resource on the system.
  #[For regular users:] all remote resources that belong to a group to which the user belongs.
  def self.find_accessible_by_user(id, user, options = {})
    scope = self.scoped(options)
    
    unless user.has_role? :admin
      scope = scope.scoped(:joins  => :user)
      
      if user.has_role? :site_manager
        scope = scope.scoped(:conditions  => ["(remote_resources.user_id = ?) OR (remote_resources.group_id IN (?)) OR (users.site_id = ?)", user.id, user.group_ids, user.site_id])
      else                   
        scope = scope.scoped(:conditions  => ["(remote_resources.user_id = ?) OR (remote_resources.group_id IN (?))", user.id, user.group_ids])
      end
    end
    
    scope.find(id)
  end
  
  #Find all remote resources accessible by +user+.
  #
  #*Accessible* remote resources  are:
  #[For *admin* users:] any remote resource on the system.
  #[For regular users:] all remote resources that belong to a group to which the user belongs.
  def self.find_all_accessible_by_user(user, options = {})
    scope = self.scoped(options)
    
    unless user.has_role? :admin
      scope = scope.scoped(:joins  => :user)
      
      if user.has_role? :site_manager
        scope = scope.scoped(:conditions  => ["(remote_resources.user_id = ?) OR (remote_resources.group_id IN (?)) OR (users.site_id = ?)", user.id, user.group_ids, user.site_id])
      else                   
        scope = scope.scoped(:conditions  => ["(remote_resources.user_id = ?) OR (remote_resources.group_id IN (?))", user.id, user.group_ids])
      end
    end
    
    scope.find(:all)
  end



  ############################################################################
  # ActiveRecord callbacks
  ############################################################################

  # When a remote resource is destroyed, clean up the SyncStatus table
  def after_destroy
    rr_id = self.id
    SyncStatus.find(:all, :conditions => { :remote_resource_id => rr_id }).each do |ss|
      ss.destroy rescue true
    end
    true
  end



  ############################################################################
  # Network Connection Methods
  ############################################################################

  # Returns (and creates if necessary) the master SSH connection
  # for this RemoteResource. The method does not start it, if
  # it's created.
  def ssh_master
    master = SshTunnel.find_or_create(self.ssh_control_user,self.ssh_control_host,self.ssh_control_port || 22)
    master
  end

  # This sets up and starts a SSH master connection to the host
  # on which the RemoteResource is running, and optionally configures
  # any or both of two supplemental tunnels: a forward tunnel to
  # carry the ActiveResource connections, and a reverse
  # tunnel to carry the ActiveRecord DB connection. The
  # tunnels are set up if the following attributes
  # are set:
  #
  # *tunnel_mysql_port*:: Optional; must be an unused port number on the remote
  #                       side where it will expect to connect to the DB server. Setting
  #                       a value to this attribute means that the remote database.yml
  #                       file will get rewritten automatically.
  # *tunnel_actres_port*:: Optional; must be an unused port number on the remote
  #                        side that it will open as its HTTP acceptor (it will become
  #                        the argument to the "-p" option for its "script/server").
  #                        The Rails app over there will tunnel its requests to it
  #                        using a port number of (3090 + the ID of the remote resource).
  def start_tunnels
    
    return false if self.id == CBRAIN::SelfRemoteResourceId
    return false unless self.online?
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
    return false unless master.start("#{self.class.to_s}_#{self.name}")
    true
  end

  # This stops the master SSH connection to the remote resource,
  # including any present tunnels. This can seriously affect
  # the remote resource if DB tunneling is in effect, as it
  # will kill its DB connection! Otherwise, the remote
  # resource is not affected.
  def stop_tunnels
    return false if self.id == CBRAIN::SelfRemoteResourceId
    return false unless self.has_ssh_control_info?
    master = self.ssh_master
    master.stop if master
    true
  end

  # Check that the remote resource has enough info configured
  # to establish as SSH master connection to it.
  def has_ssh_control_info?
    return true if
      ( ! self.ssh_control_user.blank? ) &&
      ( ! self.ssh_control_host.blank? )
    false
  end

  # Check that the remote resource has enough info configured
  # to establish as SSH master connection to it and
  # control the remote rails application.
  def has_remote_control_info?
     return true if
       (   self.has_ssh_control_info?        ) &&
       ( ! self.ssh_control_rails_dir.blank? )
     false
  end

  # Returns true if this remote resource is configued
  # for DB tunneling
  def has_db_tunneling_info? #:nodoc:
    return true if self.has_ssh_control_info? && ( ! self.tunnel_mysql_port.blank? )
    false
  end

  # Returns true if this remote resource is configued
  # for ActiveResource tunneling
  def has_actres_tunneling_info? #:nodoc:
    return true if self.has_ssh_control_info? && ( ! self.tunnel_actres_port.blank? )
    false
  end



  ############################################################################
  # Authentication Token Methods
  ############################################################################

  # This method makes sure that +token+ represents
  # one of the RemoteResource object (it's compared
  # to the values of the field +cache_md5+ ). It returns
  # the remote resource object found if successful.
  def self.valid_token?(token)
    RemoteResource.find(:first, :conditions => { :cache_md5 => token })
  end

  # Returns a constant HEX token representing a unique,
  # non obvious key for the resource. Right now we've chosen
  # the +cache_md5+ attribute of the RemoteResource.
  def auth_token
     cache_md5
  end

  ############################################################################
  # Network Control Protocol Methods
  ############################################################################

  # Checks if this remote resource is available or not.
  # This must be a live check, not cached. A cached
  # way to check the state of the resoruce is to use the
  # info() method, which caches the information record.
  def is_alive?
    info = self.remote_resource_info
    return false if info.name == "???"
    @info = info # just a quick optimization
    true
  rescue
    false
  end

  # Returns this RemoteResource's URL. This URL is adjusted
  # depending on whether or not the ActiveResource
  # connection is tunneled through a SSH master connection.
  # In the case of a tunnel, the connection is established
  # to host localhost, on a port number equal to (3090 +
  # the ID of the resource).
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

  # Returns a RemoteResourceInfo object describing the
  # basic properties of the current RemoteResource.
  # This is a class method, as it only makes sense
  # in the context of the current Rails application.
  # For remote Rails applications, the instance method
  # with the same name can be called.
  def self.remote_resource_info

    myself             = self.current_resource
    home               = CBRAIN::Rails_UserHome
    host_uptime        = `uptime 2>/dev/null`.strip   # TODO make more robust
    elapsed            = Time.now.localtime - CBRAIN::Startup_LocalTime
    @@ssh_public_key ||= `cat #{home}/.ssh/id_rsa.pub 2>/dev/null`   # TODO make more robust
    @@host_name      ||= Socket.gethostname
    @@host_ip        ||= ""
    @@host_uname     ||= `uname -a`.strip

    if @@host_ip == ""
      hostinfo = ( Socket.gethostbyname(@@host_name) rescue [ nil, nil, nil, "\000\000\000\000" ] )
      hostinfo[3].each_byte do |b|
        @@host_ip += "." unless @@host_ip.blank?
        @@host_ip += b.to_s
      end
    end

    revinfo = { 'Revision'            => 'unknown',
                'Last Changed Author' => 'unknown',
                'Last Changed Rev'    => 'unknown',
                'Last Changed Date'   => 'unknown'
              }

    IO.popen("svn info #{RAILS_ROOT} 2>/dev/null","r") do |fh|
      fh.each do |line|
        if line.match(/^Revision|Last Changed/i)
          comps = line.split(/:\s*/,2)
          field = comps[0]
          value = comps[1].gsub!(/\s*$/,"")
          revinfo[field]=value
        end
      end
    end

    info = RemoteResourceInfo.new(

      # Rails application info
      :id                 => myself.id,
      :name               => myself.name,
      :uptime             => elapsed,

      # Host info
      :host_name          => @@host_name,
      :host_ip            => @@host_ip,
      :host_uname         => @@host_uname,
      :host_uptime        => host_uptime,
      :ssh_public_key     => @@ssh_public_key,

      # Svn info
      :revision           => revinfo['Revision'],
      :lc_author          => revinfo['Last Changed Author'],
      :lc_rev             => revinfo['Last Changed Rev'],
      :lc_date            => revinfo['Last Changed Date']

    )

    return info
  end

  # Connects to the remote resource's information channel
  # (Control) and get a record of run-time information. It is
  # usually better to call the info method instead, which will
  # cache the result if necessary. See also the class method
  # of the same name if you're interested in the information
  # about the current Rails application.
  def remote_resource_info

    # In case we're asking about the CURRENT Rails
    # app, no need to connect to the network, eh?
    if self.id == CBRAIN::SelfRemoteResourceId
      return self.class.remote_resource_info
    end

    @info = nil
    begin
      if self.start_tunnels
        Control.site    = self.site
        Control.timeout = 10
        control_info = Control.find('info')
        @info = RemoteResourceInfo.new(control_info.attributes)
      end
    rescue
      # oops, it's dead
    end

    # If we can't find the info, we return a
    # plain dummy record containing mostly
    # strings of '???' everywhere.
    @info ||= RemoteResourceInfo.dummy_record

    @info
  end

  # Returns and cache a record of run-time information about the resource.
  # This method automatically calls update_info if the information has
  # not been cached yet.
  def info
    @info ||= self.remote_resource_info
    @info
  end

  # Utility method to send a clean_cache command to a
  # RemoteResource, whether local or not.
  def send_command_clean_cache(userlist,older_than)
    if older_than.is_a?(Fixnum)
       time_limit = older_than.seconds.ago
    elsif older_than.is_a?(Time)
       time_limit = older_than
    else
       cb_error "Invalid time offset for clean_cache command."
    end
    userlist = [ userlist ] unless userlist.is_a?(Array)
    useridlist = userlist.map { |u| u.is_a?(User) ? u.id.to_s : u.to_s }.join(",")
    command = RemoteCommand.new(
      :command     => 'clean_cache',
      :user_ids    => useridlist,
      :before_date => time_limit
    )
    send_command(command)
  end

  # Utility method to send a start_workers command to a
  # RemoteResource, whether local or not.
  def send_command_start_workers
    command = RemoteCommand.new(
      :command     => 'start_workers'
    )
    send_command(command)
  end

  # Utility method to send a stop_workers command to a
  # RemoteResource, whether local or not.
  def send_command_stop_workers
    command = RemoteCommand.new(
      :command     => 'stop_workers'
    )
    send_command(command)
  end

  # Send a command object to the remote resource.
  # The command will either be delivered through the
  # network channel as an ActiveResource, or directly
  # sent to the local RemoteResource object if the
  # destination is local.
  def send_command(command)
    cb_error "Not a command object" unless command.is_a?(RemoteCommand)

    # Record sender and receiver tokens
    command.sender_token   = RemoteResource.current_resource.auth_token
    command.receiver_token = self.auth_token

    # Send local
    if self.id == CBRAIN::SelfRemoteResourceId
      return self.class.process_command(command)
    end

    # Send remote
    Control.site    = self.site
    Control.timeout = 10
    control = Control.new(command)
    control.save

  end



  ############################################################################
  # RemoteCommand Processing on local resource
  ############################################################################

  # Process a RemoteCommand object on the current RemoteResource
  def self.process_command(command)

    cb_error "Command object doesn't have a command." unless command.command

    myself = RemoteResource.current_resource

    # Check that I'm the proper receiver
    receiver_token = command.receiver_token || "-nope-"
    if myself.auth_token != receiver_token
      Message.send_message( User.find_by_login('admin'),
        { :message_type  => :error,
          :header        => "RemoteResource #{myself.name} got message intended for someone else.",
          :variable_text => command.to_xml
        }
      )
      return
    end

    # Check that the sender is legitimate
    sender_token   = command.sender_token || "-nope-"
    sender = RemoteResource.valid_token?(sender_token)
    if !sender
      Message.send_message( User.find_by_login('admin'),
        { :message_type  => :error,
          :header        => "RemoteResource #{myself.name} got message from unknown source.",
          :variable_text => command.to_xml
        }
      )
      return
    end

    puts "RemoteResource Processing Command: #{command.inspect}"

    if command.command == "clean_cache"
      self.process_command_clean_cache(command.user_ids, command.before_date)
    elsif command.command == "start_workers"
      self.process_command_worker_control('start')
    elsif command.command == "stop_workers"
      self.process_command_worker_control('stop')
    else
      cb_error "Unknown command #{command.command}"
    end
  end

  protected

  # Clean the cached files of a list of users, for file
  # last accessed before the +before_date+ ; the task
  # is start in background, as it can be long.
  def self.process_command_clean_cache(userids, before_date = Time.now)
    userlist = []
    userids.split(/,/).uniq.each do |idstring|
      if idstring == 'all'
        userlist |= User.all
        next
      end
      uid = idstring.to_i
      userlist << User.find(uid)
    end
    userlist.compact!
    userlist.uniq!

    CBRAIN::spawn_with_active_records(User.find_by_login('admin'),"Cache Cleanup") do
      targetfiles = Userfile.find(:all, :conditions => { :user_id => userlist })
      targetfiles.each do |userfile|
        syncstatus = userfile.local_sync_status rescue nil
        next if syncstatus && syncstatus.accessed_at >= before_date
        userfile.data_provider.cache_erase(userfile)
      end
    end

    true
  end

  # Starts or stops Bourreau worker processes
  def self.process_command_worker_control(startstop)
    myself = RemoteResource.current_resource
    cb_error "Got worker control command #{startstop} but I'm not a Bourreau!" unless
      myself.is_a?(Bourreau)
    if startstop == 'start'
      self.start_bourreau_workers
    elsif startstop == 'stop'
      BourreauWorker.signal_all('TERM')
    else
      cb_error "Got unknown worker control command #{startstop}"
    end
  end

  # This just makes sure some workers are available.
  # It's unfortunate that due to technical reasons,
  # such workers cannot be started when the application
  # boots (CBRAIN.spawn_with_active_records() won't work
  # properly until RAILS is fully booted).
  def self.start_bourreau_workers
    allworkers = BourreauWorker.all
    return true if allworkers.size >= CBRAIN::BOURREAU_WORKERS_INSTANCES
    while allworkers.size < CBRAIN::BOURREAU_WORKERS_INSTANCES
      # For the moment we only start one worker, but
      # in the future we may want to start more than one,
      # once we're sure they don't interfere with each other.
      worker = BourreauWorker.new
      worker.check_interval = CBRAIN::BOURREAU_WORKERS_CHECK_INTERVAL # in seconds, default is 55
      worker.bourreau       = self.current_resource                   # Optional, when logging to Bourreau's log
      worker.log_to         = CBRAIN::BOURREAU_WORKERS_LOG_TO         # 'stdout,bourreau'
      worker.verbose        = CBRAIN::BOURREAU_WORKERS_VERBOSE        # if we want each job action logged!
      worker.launch
      allworkers = BourreauWorker.all
    end
    true
  end

end
