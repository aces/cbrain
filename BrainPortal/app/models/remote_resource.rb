
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
#=General Attributes:
#[*name*] A string representing a the name of the remote resource.
#[*online*] A boolean value set to whether or not the resource is online.
#[*read_only*] A boolean value set to whether or not the resource is read only.
#[*description*] Text with a description of the remote resource.
#
#==ActiveResource Attributes:
#[*actres_user*] Username for the remote resource's ActiveResource connection;
#                this is most often not used.
#[*actres_host*] Hostname of the remote resource's ActiveResource connection.
#[*actres_port*] The port number of the remote resource's ActiveResource connection.
#[*actres_dir*] The directory prefix of the remote resource's ActiveResource connection;
#               this is most often empty.
#
#==SSH Connection Attributes:
#[*ssh_control_user*] Username of the UNIX account running the remote resource's Rails application.
#[*ssh_control_host*] Hostname of the machine running the remote resource's Rails application.
#[*ssh_control_port*] SSH port number of the machine running the remote resource's Rails application.
#[*ssh_control_rails_dir*] Rails root directory where the remote resource is installed.
#
#==Optional Tunneling Port Numbers Attributes:
#[*tunnel_mysql_port*] Used by a BrainPortal to offer its ActiveRecord DB connection to the
#                      remote resource through a tunnel; this works only when the SSH
#                      connection attributes are properly configured.
#[*tunnel_actres_port*] Used by a BrainPortal to tunnel the remote resource's ActiveResource
#                       connection; this works only when the SSH connection attributes
#                       are properly configured. When in use, the ActiveResource attributes
#                       above are ignored.
#
#= Associations:
#*Belongs* *to*:
#* User
#* Group
class RemoteResource < ActiveRecord::Base

  Revision_info="$Id$"
  
  include ResourceAccess

  validates_uniqueness_of :name
  validates_presence_of   :name, :user_id, :group_id
  validates_format_of     :name, :with  => /^[a-zA-Z0-9][\w\-\=\.\+]*$/,
                                 :message  => 'only the following characters are valid: alphanumeric characters, _, -, =, +, ., ?, !',
                                 :allow_blank => true

  belongs_to  :user
  belongs_to  :group
  has_many    :sync_status



  ############################################################################
  # Current Rails Resource information
  ############################################################################

  # Returns the RemoteResource object representing
  # the current Rails application.
  def self.current_resource
    #@@current_resource ||= self.find(CBRAIN::SelfRemoteResourceId)
    self.find(CBRAIN::SelfRemoteResourceId)
  end

  # Returns a copy of the Rails DB configuration hash currently
  # being used. This is a hash representing one DB config in
  # database.yml.
  def self.current_resource_db_config(railsenv = nil)
    railsenv ||= (ENV["RAILS_ENV"] || 'production')
    myconfigs  = ActiveRecord::Base.configurations
    myconfig   = myconfigs[railsenv].dup
    myconfig
  end



  ############################################################################
  # Access Control Methods
  ############################################################################

  # Returns the site associated with the owner of this
  # remote resource.
  def site_affiliation
    @site_affiliation ||= self.user.site
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
    master = SshTunnel.find_or_create(self.ssh_control_user,self.ssh_control_host,self.ssh_control_port || 22,self.class.to_s)
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
  #                        The Rails application over there will tunnel its requests to it
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
      myconfig        = self.class.current_resource_db_config
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
  # Remote Shell Command methods
  #
  # These two methods prepend the constant shell statements
  #   "source /path/to/cbrain_bashrc;"
  # to the specified shell command and then call the corresponding command
  # execution methods of the master ssh_tunnel for the RemoteResource.
  ############################################################################

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
  def read_from_remote_shell_command(shell_command, options={}, &block)
    cb_error "No proper SSH control info provided for RemoteResource." unless self.has_ssh_control_info?
    master = self.ssh_master
    cb_error "No SSH master connection yet established for RemoteResource." unless master.is_alive?
    shell_commands = prepend_source_cbrain_bashrc(shell_command)
    master.remote_shell_command_reader(shell_commands, options, &block)
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
  def write_to_remote_shell_command(shell_command, options={}, &block)    
    cb_error "No proper SSH control info provided for RemoteResource." unless self.has_ssh_control_info?
    master = self.ssh_master
    cb_error "No SSH master connection yet established for RemoteResource." unless master.is_alive?
    shell_commands = prepend_source_cbrain_bashrc(shell_command)
    master.remote_shell_command_writer(shell_commands, options, &block)
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
  # way to check the state of the resource is to use the
  # info() method, which caches the information record.
  def is_alive?
    return false if self.online == false 
    @info = self.remote_resource_info
    if @info.name == "???"
      self.time_of_death ||= Time.now
      if self.time_of_death < 2.minutes.ago
        self.time_of_death = Time.now
      elsif self.time_of_death < Time.now
        self.online = false
      end
      self.save
      return false
    end
    self.time_of_death = nil
    self.save
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
    time_zone_name     = Time.zone ? Time.zone.name : ""

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
      :rails_time_zone    => time_zone_name,
      :ssh_public_key     => @@ssh_public_key,

      # Svn info
      :revision           => revinfo['Revision'],
      :lc_author          => revinfo['Last Changed Author'],
      :lc_rev             => revinfo['Last Changed Rev'],
      :lc_date            => revinfo['Last Changed Date'],
      :starttime_revision => $CBRAIN_StartTime_Revision

    )

    # Cache the time zone name in the current resource.
    if ! time_zone_name.blank? && (myself.time_zone.blank? || myself.time_zone != time_zone_name)
      myself.time_zone = time_zone_name
      myself.save
    end

    return info
  end

  # Connects to the remote resource's information channel
  # (Control) and get a record of run-time information. It is
  # usually better to call the info method instead, which will
  # cache the result if necessary. See also the class method
  # of the same name if you're interested in the information
  # about the current Rails application (which will be
  # called anyway if you call this instance method on the
  # remote resource object which represents the current Rails
  # app).
  def remote_resource_info

    # In case we're asking about the CURRENT Rails
    # app, no need to connect to the network, eh?
    if self.id == CBRAIN::SelfRemoteResourceId
      return self.class.remote_resource_info
    end

    info = nil
    begin
      if !self.has_ssh_control_info? || (self.ssh_master && self.ssh_master.is_alive?)
        Control.site    = self.site
        Control.timeout = 30
        control_info = Control.find('info')
        info = RemoteResourceInfo.new(control_info.attributes)
      end
    rescue => ex
      # Oops, it's dead
      #puts "Control connection to remote_resource '#{self.name}' (#{self.id}) failed:"
      #puts "Exception=#{ex.to_s}\n#{ex.backtrace.join("\n")}"
    end

    # If we can't find the info, we return a
    # plain dummy record containing mostly
    # strings of '???' everywhere.
    info ||= RemoteResourceInfo.dummy_record

    info
  end

  # Returns and cache a record of run-time information about the resource.
  # This method automatically calls update_info if the information has
  # not been cached yet.
  def info
    return @info if @info
    @info = RemoteResourceInfo.dummy_record unless is_alive? # is_alive?() fills @info as a side effect
    @info
  end




  ############################################################################
  # Utility Shortcuts To Send Commands
  ############################################################################

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

  # Utility method to send a +start_workers+ command to a
  # RemoteResource, whether local or not.
  # Maybe this should be more specific to Bourreaux.
  def send_command_start_workers
    command = RemoteCommand.new(
      :command     => 'start_workers'
    )
    send_command(command)
  end

  # Utility method to send a +stop_workers+ command to a
  # RemoteResource, whether local or not.
  # Maybe this should be more specific to Bourreaux.
  def send_command_stop_workers
    command = RemoteCommand.new(
      :command     => 'stop_workers'
    )
    send_command(command)
  end


  # Utility method to send a +wakeup_workers+ command to a
  # RemoteResource, whether local or not.
  # Maybe this should be more specific to Bourreaux.
  def send_command_wakeup_workers
    command = RemoteCommand.new(
      :command     => 'wakeup_workers'
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

    returned_command = RemoteCommand.new(control.attributes)
    return returned_command
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
    
    self.send("process_command_#{command.command}", command)
    # if command.command == "clean_cache"
    #   self.process_command_clean_cache(command.user_ids, command.before_date)
    # elsif command.command =~ /^(start|stop|wakeup)_workers/
    #   self.process_command_worker_control(Regexp.last_match[1])
    # else
    #   cb_error "Unknown command #{command.command}"
    # end
  end
  
  #Treat process_command_xxx calls as bad commands,
  #otherwise as NoMethodErrors
  def self.method_missing(method, *args)
    if method.to_s =~ /^process_command_(.+)/
      cb_error "Unknown command #{Regexp.last_match[1]}"
    else
      super
    end
  end



  ############################################################################
  # Commands Implemented by all RemoteResources
  ############################################################################

  protected

  # Clean the cached files of a list of users, for files
  # last accessed before the +before_date+ ; the task
  # is started in background, as it can be long.
  def self.process_command_clean_cache(command)
    user_ids     = command.user_ids
    before_date = command.before_date || Time.now
    
    userlist = []
    user_ids.split(/,/).uniq.each do |idstring|
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
        #dp = userfile.data_provider
        #next unless dp.online?
        userfile.cache_erase
      end
    end

    true
  end

  # Helper method to prepend 'source cbrain_bashrc;' to shell command.
  # The 'cbrain_bashrc' script is the one located in
  # the "/script" subdirectory under the remote resource's
  # RAILS root directory. Normally it's empty.
  def prepend_source_cbrain_bashrc(shell_command)
    cbrain_bashrc_path = self.ssh_control_rails_dir + "/script/cbrain_bashrc"
    return "source #{cbrain_bashrc_path}; #{shell_command}"
  end

end
