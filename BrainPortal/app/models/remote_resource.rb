
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

require 'socket'

#Model representing a remote resource, which is always a
#Rails applications with a 'controls' controller. Typically,
#the remote Rails application is a Bourreau or a BrainPortal,
#or the current Rails application running locally.
#
#==General Attributes:
#[*name*] A string representing a the name of the remote resource.
#[*online*] A boolean value set to whether or not the resource is online.
#[*read_only*] A boolean value set to whether or not the resource is read only.
#[*description*] Text with a description of the remote resource.
#
#==SSH Connection Attributes:
#[*ssh_control_user*] Username of the UNIX account running the remote resource's Rails application.
#[*ssh_control_host*] Hostname of the machine running the remote resource's Rails application.
#[*ssh_control_port*] SSH port number of the machine running the remote resource's Rails application.
#[*ssh_control_rails_dir*] Rails root directory where the remote resource is installed.
#
#= Associations:
#*Belongs* *to*:
#* User
#* Group
class RemoteResource < ApplicationRecord

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  include ResourceAccess
  include LicenseAgreements

  cbrain_abstract_model! # objects of this class are not to be instanciated

  serialize             :dp_ignore_patterns

  # These are the ActionMailer's delivery_method_options, and for the moment
  # can only be set by the admin using the Rails console; leaving them blank
  # means the mailers use whatever is configured in the Rails environment config.
  serialize             :email_delivery_options

  validates             :name,
                        :uniqueness        => true,
                        :presence          => true,
                        :identifier_format => true

  validates_presence_of :user_id, :group_id

  validate              :proper_dp_ignore_patterns
  validate              :dp_cache_path_valid

  validates_format_of   :cms_shared_dir, :with => /\A[\w\-\.\=\+\/]*\z/,
                        :message  => 'is invalid as only paths with simple characters are valid: a-z, A-Z, 0-9, _, +, =, . and of course /',
                        :allow_blank => true

  validates_format_of   :dp_cache_dir, :with => /\A[\w\-\.\=\+\/]*\z/,
                        :message  => 'is invalid as only paths with simple characters are valid: a-z, A-Z, 0-9, _, +, =, . and of course /',
                        :allow_blank => true

  validates_format_of   :ssh_control_user, :with => /\A\w[\w\-\.]*\z/,
                        :message  => 'is invalid as only the following characters are valid: alphanumeric characters, _, -, and .',
                        :allow_blank => true

  validates_format_of   :ssh_control_host, :with => /\A\w[\w\-\.]*\z/,
                        :message  => 'is invalid as only the following characters are valid: alphanumeric characters, _, -, and .',
                        :allow_blank => true

  validates_format_of   :ssh_control_rails_dir, :with => /\A[\w\-\.\=\+\/]*\z/,
                        :message  => 'is invalid as only paths with simple characters are valid: a-z, A-Z, 0-9, _, +, =, . and of course /',
                        :allow_blank => true

  belongs_to            :user
  belongs_to            :group
  has_many              :sync_status
  has_many              :background_activities, :dependent => :destroy

  # Resource usage is kept forever even if remote resource is destroyed.
  has_many              :resource_usage

  after_destroy         :after_destroy_clean_sync_status



  ############################################################################
  # Pseudo-attributes Access
  ############################################################################

  # Used by interface so that users can get the list of ignore patterns
  # as a single space-separated string.
  def spaced_dp_ignore_patterns #:nodoc:
    ip = self.dp_ignore_patterns || []
    ip.join("     ")
  end

  # Used by interface so that users can set the list of ignore patterns
  # as a single space-separated string.
  def spaced_dp_ignore_patterns=(spaced_vals = "") #:nodoc:
    ip = spaced_vals.split(/\s+/).reject { |u| u.blank? }
    self.dp_ignore_patterns = ip
  end



  ############################################################################
  # Current Rails Resource information
  ############################################################################

  # Returns the RemoteResource object representing
  # the current Rails application.
  def self.current_resource
    self.find(CBRAIN::SelfRemoteResourceId) # not cached; multiple instances of mongrel!
  end

  # Returns a copy of the Rails DB configuration hash currently
  # being used. This is a hash representing one DB config in
  # database.yml.
  def self.current_resource_db_config(railsenv = nil)
    railsenv ||= (Rails.env || 'production')
    myconfigs  = ApplicationRecord.configurations
    myconfig   = myconfigs[railsenv].dup
    myconfig
  end

  ############################################################################
  # ActiveRecord callbacks
  ############################################################################

  # When a remote resource is destroyed, clean up the SyncStatus table
  def after_destroy_clean_sync_status
    rr_id = self.id
    SyncStatus.where( :remote_resource_id => rr_id ).each do |ss|
      ss.destroy rescue true
    end
    true
  end

  # Verify that the ignore patterns are correct.
  def proper_dp_ignore_patterns

    ig_pat = self.dp_ignore_patterns || [] # nil and [] are ok
    unless ig_pat.is_a?(Array)
      errors.add(:dp_ignore_patterns,"is not an array.")
      return false
    end

    all_ok = true

    ig_pat.each do |pattern|
      if (! pattern.is_a?(String)) ||
        pattern.blank? ||
        pattern == "*" ||
        ! pattern.is_a?(String) ||
        pattern =~ /\*\*/ ||
        pattern =~ /\// ||
        pattern !~ /\A[\w\-\.\+\=\@\%\&\:\,\~\*\?]+\z/ # very strict! other special characters can cause shell side-effects!
        errors.add(:spaced_dp_ignore_patterns, "has unacceptable pattern: '#{pattern}'." )
        all_ok = false
      end
    end

    all_ok
  end

  # Verify that the dp_cache_dir is correct, at least from
  # what we can see. It's possible to edit the path of an
  # external RemoteResource, so we can't check that the dir
  # exist over there.
  def dp_cache_path_valid
    path = self.dp_cache_dir

    return true if path.blank?  # We allow this even if it won't work, until the admin sets it.

    if path !~ /\A\//
      errors.add(:dp_cache_dir, "must be an absolute path.")
      return false
    end

    begin
      is_local = self.id && self.id == CBRAIN::SelfRemoteResourceId
      valid = DataProvider.this_is_a_proper_cache_dir! path,
        :local                  => is_local,
        :key                    => self.cache_md5.presence || "unset",  # having this string forces the check
        :host                   => is_local ? Socket.gethostname : self.ssh_control_host,
        :for_remote_resource_id => self.id
      unless valid
        errors.add(:dp_cache_dir," is invalid (does not exist, is unaccessible, contains data or is a system directory).")
        return false
      end
    rescue => ex
      errors.add(:dp_cache_dir," is invalid: #{ex.message}")
      return false
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
    # SSH connect options are normally just the default ones,
    # but an admin can override them in the meta data of the object.
    # The SSH agent forwarding is mandatory however.
    ssh_options = (self.meta[:ssh_config_options].presence || {})
                  .dup.merge( :ForwardAgent => 'yes' )
    # category: we add the UNIX userid so as not to conflict
    # with any other user on the system when creating out socket in /tmp
    category = "#{self.class}_#{Process.uid}"
    uniq     = "#{self.id}"
    master   = SshMaster.find_or_create(self.ssh_control_user,self.ssh_control_host,self.ssh_control_port || 22,
               :category => category, :uniq => uniq, :ssh_config_options => ssh_options )
    master
  end

  # This sets up and starts a SSH master connection to the host
  # on which the RemoteResource is running, and optionally configures
  # any or both of two supplemental tunnels: a forward tunnel to
  # carry the ActiveResource connections, and a reverse
  # tunnel to carry the ActiveRecord DB connection.
  def start_tunnels

    return false if self.id == CBRAIN::SelfRemoteResourceId
    return false unless self.online?
    return false unless self.has_ssh_control_info?

    # Setup SSH master connection
    master = self.ssh_master
    return true if master.is_alive?  # we don't reconfigure if already alive

    master.delete_tunnels(:forward)
    master.delete_tunnels(:reverse)

    # Setup DB reverse tunnel
    myconfig        = self.class.current_resource_db_config
    local_db_host   = myconfig["host"]  || "localhost"
    local_db_port   = (myconfig["port"] || "3306").to_i
    rnd             = 1000000+rand(9999999)
    master.add_tunnel(:reverse,
      (Pathname.new(self.ssh_control_rails_dir) + "tmp/sockets/db.#{rnd}.sock").to_s,
      local_db_host,
      local_db_port,
      nil # nil is important here
    )

    # Setup ActiveResource forward tunnel
    local_port  = 3090+self.id # see also in site()
    master.add_tunnel(:forward,
      local_port,
      nil, # nil is important here
      (Pathname.new(self.ssh_control_rails_dir) + "tmp/sockets/bourreau.sock").to_s
    )

    # If the SSH master and tunnels have already been started by
    # another instance, the following will simply do nothing.
    CBRAIN.with_unlocked_agent if ! master.quick_is_alive? # unlock the agent so we can establish the tunnel
    return false unless master.start("#{self.class.to_s}_#{self.name}")
    true
  end

  # This stops the master SSH connection to the remote resource,
  # including any present tunnels. This can seriously affect
  # the remote resource if DB tunnelling is in effect, as it
  # will kill its DB connection! Otherwise, the remote
  # resource may not be affected.
  def stop_tunnels
    return false if self.id == CBRAIN::SelfRemoteResourceId
    return false unless self.has_ssh_control_info?
    master = self.ssh_master
    master.destroy if master
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

  # Returns the SSH address of the bourreau in
  # "user@hostname" format. If options[:port] is true
  # it will return it in "user@hostname:port" format.
  # Raises an exception if the information is not available.
  def ssh_address_string(options={})
    cb_error "No SSH control information available." unless self.has_ssh_control_info?
    base  = "#{self.ssh_control_user}@#{self.ssh_control_host}"
    base += ":#{self.ssh_control_port.presence || 22}" if options[:port]
    base
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



  ############################################################################
  # Remote Shell Command methods
  #
  # These two methods prepend the constant shell statements
  #   "source /path/to/cbrain_bashrc;"
  # to the specified shell command and then call the corresponding command
  # execution methods of the ssh_master for the RemoteResource.
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
    RemoteResource.where( :cache_md5 => token ).first
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
  def is_alive?(what = :ping)
    what = what.presence.try(:to_sym) || :ping
    self.reload
    return false if self.online == false
    info_struct = self.remote_resource_info(what) # what is 'info' or 'ping'
    @info = info_struct if what == :info
    @ping = info_struct if what == :ping
    if info_struct.name != "???"
      self.update_attributes( :time_of_death => nil ) if self.time_of_death
      return true
    end
    self.update_attributes( :time_of_death => Time.now ) unless self.time_of_death
    if self.time_of_death < 2.minutes.ago
      self.update_attributes( :time_of_death => Time.now )
    elsif self.time_of_death >= 2.minutes.ago && self.time_of_death < 10.seconds.ago
      self.update_attributes( :online => false )
    end
    return false
  rescue
    false
  end

  # Returns this RemoteResource's URL. This URL maps to a
  # connection tunnelled through a SSH master connection.
  # The connection is established to host localhost, on a port
  # number equal to (3090 + the ID of the resource).
  def site
    host = "localhost"
    port = 3090+self.id  # see also in start_tunnels()
    "http://#{host}:#{port}"
  end

  # Returns a RemoteResourceInfo object describing the
  # basic properties of the current RemoteResource.
  # This is a class method, as it only makes sense
  # in the context of the current Rails application.
  # For remote Rails applications, the instance method
  # with the same name can be called, which will fetch
  # the info via the Controls channel.
  def self.remote_resource_info
    myself            = self.current_resource
    host_uptime       = `uptime 2>/dev/null`.strip   # TODO make more robust
    elapsed           = Time.now.localtime - CBRAIN::Startup_LocalTime
    @host_name      ||= Socket.gethostname
    @host_ip        ||= ""
    @host_uname     ||= `uname -a`.strip
    time_zone_name    = Time.zone ? Time.zone.name : ""

    if @host_ip == ""
      hostinfo = ( Socket.gethostbyname(@host_name) rescue [ nil, nil, nil, "\x00\x00\x00\x00" ] )
      hostinfo[3].each_byte do |b|
        @host_ip += "." unless @host_ip.blank?
        @host_ip += b.to_s
      end
    end

    # Extract GIT information from the file system
    @git_commit ||= "" # fetched only once.
    @git_author ||= "" # fetched only once.
    @git_date   ||= "" # fetched only once.
    if @git_commit.blank?
      head_rev = CbrainFileRevision.cbrain_head_revinfo
      @git_commit = head_rev.commit
      @git_author = head_rev.author
      @git_date   = "#{head_rev.date} #{head_rev.time}"
    end

    # @git_tag will be the most recent tag in GIT, appended with
    # "-num" for the number of commits that follows until HEAD.
    # The value is live, to highlight when the files are not the
    # same as when the Rails app started.

    @git_tag   = CbrainFileRevision.cbrain_head_tag
    @git_tag ||= "C-#{@git_commit}" # default

    info = RemoteResourceInfo.new(

      # Rails application info
      :id                 => myself.id,
      :name               => myself.name,
      :uptime             => elapsed,
      :environment        => Rails.env,

      # Host info
      :host_name          => @host_name,
      :host_ip            => @host_ip,
      :host_uname         => @host_uname,
      :host_uptime        => host_uptime,
      :rails_time_zone    => time_zone_name,

      # Source control info
      :revision           => @git_tag,                          # 'live' value
      :lc_author          => @git_author,                       # at process start
      :lc_rev             => @git_commit,                       # at process start
      :lc_date            => @git_date,                         # at process start
      :starttime_revision => CBRAIN::CBRAIN_StartTime_Revision  # at process start

    )

    return info
  end

  # Returns a lighter and faster-to-generate 'ping' information
  # for this server; the object returned is RemoteResourceInfo
  # with only a few fields set, fields that are 'quick' to
  # generate.
  def self.remote_resource_ping
    rr                      = RemoteResource.current_resource
    info                    = RemoteResourceInfo.new
    info.id                 = rr.id
    info.name               = rr.name
    info.starttime_revision = CBRAIN::CBRAIN_StartTime_Revision
    info.uptime             = Time.now.localtime - CBRAIN::Startup_LocalTime
    info.environment        = Rails.env
    info
  end

  def get_ssh_public_key #:nodoc:
    cb_error "SSH public key only accessible for the current resource." unless self.id == self.class.current_resource.id
    return @ssh_public_key if @ssh_public_key
    home = CBRAIN::Rails_UserHome
    if File.exists?("#{home}/.ssh/id_cbrain_ed25519.pub")
      @ssh_public_key = File.read("#{home}/.ssh/id_cbrain_ed25519.pub") rescue ""
    else
      @ssh_public_key = ""
    end
    @ssh_public_key
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
  def remote_resource_info(what = :info)

    what = what.presence.try(:to_sym) || :info

    # In case we're asking about the CURRENT Rails
    # app, no need to connect to the network, eh?
    if self.id == CBRAIN::SelfRemoteResourceId
      return self.class.remote_resource_info if what == :info
      return self.class.remote_resource_ping if what == :ping
      raise "Unknown info keyword '#{what}'."
    end

    info = nil
    begin
      # We used to support direct ActiveResource connections to a Bourreau, but not anymore.
      # We expect them all to go through SSH tunnels, now.
      if self.ssh_master && self.ssh_master.is_alive?
        Control.site    = self.site
        Control.timeout = (self.rr_timeout.blank? || self.rr_timeout < 30) ? 30 : self.rr_timeout
        control_info = Control.find(what) # asks for controls/info.xml or controls/ping.xml
        info = RemoteResourceInfo.new(control_info.attributes)
      end
    rescue
      # Oops, it's dead
      # puts "Control connection to remote_resource '#{self.name}' (#{self.id}) failed:"
      # puts "Exception=#{ex.to_s}\n#{ex.backtrace.join("\n")}"
    end

    # If we can't find the info, we return a
    # plain dummy record containing mostly
    # strings of '???' everywhere.
    info ||= RemoteResourceInfo.dummy_record

    info
  end

  # Returns and cache a record of run-time information about the resource.
  # This is the main entry point for querying a RemoteResource, along
  # with is_alive?
  def info(what = :info)
    if self.id == CBRAIN::SelfRemoteResourceId # no caching for local
      return self.class.remote_resource_info if what == :info
      return self.class.remote_resource_ping if what == :ping
      raise "Unknown info keyword '#{what}'."
    end
    # The ping struct is a subset of info, so return info if cached
    return @info if @info # caching within Rails action
    @info = self.info_cached?(:info) # caching between Rails actions, in meta data store
    return @info if @info
    if what == :ping # see if we cached just the ping info
      return @ping if @ping # caching within Rails action
      @ping = self.info_cached?(:ping) # caching between Rails actions, in meta data store
      return @ping if @ping
    end
    running = self.is_alive?(what) # this updates @info or @ping as a side-effect
    if running
      if what == :info
        (self.meta[:info_cache]             = @info       ) rescue nil # save from rare race conditions
        (self.meta[:info_cache_last_update] = Time.now.utc) rescue nil
        return @info
      else
        (self.meta[:ping_cache]             = @ping       ) rescue nil # save from rare race condition
        (self.meta[:ping_cache_last_update] = Time.now.utc) rescue nil
        return @ping
      end
    end
    self.zap_info_cache(what)
    dummy = RemoteResourceInfo.dummy_record
    @info = dummy if what == :info
    @ping = dummy if what == :ping
    return what == :info ? @info : @ping
  end

  # Returns the info record for the resource if it is cached and
  # recent enough (less than a minute old), returns nil otherwise.
  def info_cached?(what = :info)
    date_key = "#{what}_cache_last_update".to_sym
    info_key = "#{what}_cache".to_sym
    last_meta_cached = self.meta[date_key] || 1.year.ago
    if last_meta_cached > 1.minute.ago
      info = self.meta[info_key] # caching between Rails actions
      if info
        rri = RemoteResourceInfo.new(info) # caching within a single Rails action
        @info = rri if what == :info
        @ping = rri if what == :ping
        return what == :info ? @info : @ping
      end
    end
    nil
  end

  # Zaps the cache in DB
  def zap_info_cache(what = :info)
    @info = nil if what == :info
    @ping = nil if what == :ping
    info_key = "#{what}_cache".to_sym
    self.meta[info_key] = nil # zaps cache in DB
  end




  ############################################################################
  # Utility Shortcuts To Send Commands
  ############################################################################

  # Utility method to send a clean_cache command to a
  # RemoteResource, whether local or not.
  def send_command_clean_cache(userlist,typelist,older_than,younger_than)
    if older_than.is_a?(Integer)
       time_older = older_than.seconds.ago
    elsif older_than.is_a?(Time)
       time_older = older_than
    else
       cb_error "Invalid older_than time offset for clean_cache command."
    end
    if younger_than.is_a?(Integer)
       time_younger = younger_than.seconds.ago
    elsif younger_than.is_a?(Time)
       time_younger = younger_than
    else
       cb_error "Invalid younger_than offset for clean_cache command."
    end
    userlist = [ userlist ] unless userlist.is_a?(Array)
    useridlist = userlist.map { |u| u.is_a?(User) ? u.id.to_s : u.to_s }.join(",")
    command = RemoteCommand.new(
      :command     => 'clean_cache',
      :user_ids    => useridlist,
      :types       => Array(typelist).join(","),
      :before_date => time_older,
      :after_date  => time_younger
    )
    send_command(command)
  end

  # Utility method to send a +check_data_providers+ command to a
  # RemoteResource, whether local or not. dp_ids should be
  # an array of Data Provider IDs. The command
  # does not return any useful information, it simply
  # launches a background job on the RemoteResource
  # which polls the Data Providers and store the
  # results in the meta data store.
  def send_command_check_data_providers(dp_ids=[])
    command = RemoteCommand.new(
      :command           => 'check_data_providers',
      :data_provider_ids => dp_ids
    )
    send_command(command)
  end

  # Utility method to send a +copy_files+ command to a
  # RemoteResource, whether local or not. +userfile_ids+
  # should be  an array of Userfiles to copy.
  # +dest_data_provider_id+ is the ID of the DP to copy the
  # the files to.
  # The command does not return any useful information, it simply
  # launches a background job on the RemoteResource.
  def send_command_copy_files(userfile_ids, dest_data_provider_id, requester_user_id)
    command = RemoteCommand.new(
      :command               => 'copy_files',
      :userfile_ids          => userfile_ids.join(","),
      :dest_data_provider_id => dest_data_provider_id,
      :requester_user_id     => requester_user_id,
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
      self.class.process_command(command)
      return command
    end

    # Send remote
    Control.site    = self.site
    Control.timeout = 20
    control         = Control.new(command)
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

    #puts "RemoteResource Processing Command: #{command.inspect}"
    self.send("process_command_#{command.command}", command)

  end

  # Treat process_command_xxx calls as bad commands,
  # otherwise as NoMethodErrors
  def self.method_missing(method, *args)
    if method.to_s =~ /\Aprocess_command_(.+)/
      cb_error "Unknown command #{Regexp.last_match[1]}"
    else
      super
    end
  end



  ############################################################################
  # Commands Implemented by all RemoteResources
  ############################################################################

  protected

  # Verifies a list of data providers and returns for
  # each one of three states:
  #
  #  - "notexist"    (when the DP id is invalid)
  #  - "offline"     (when the DP's attribute 'online' is false)
  #  - "alive"       ('online' is true and is_alive? is true)
  #  - "down"        ('online' is true but is_alive? is false)
  #
  # The returned states are stored in the meta data store
  # as a hash.
  def self.process_command_check_data_providers(command)
    dp_ids = command.data_provider_ids || []
    return true if dp_ids.empty?
    rr = RemoteResource.current_resource()
    last_update = rr.meta[:data_provider_statuses_last_update]
    return true if last_update && last_update > 30.seconds.ago
    CBRAIN.spawn_with_active_records(:admin, "DP Check") do
      dp_stats = {}
      dp_ids.each_with_index do |dp_id,idx|
        dp  = DataProvider.find_by_id(dp_id)
        Process.setproctitle "DP Check #{idx+1}/#{dp_ids.size}: #{dp.try(:name) || "UnknownDP"}"
        if ! dp
          stat = "notexist"
        elsif ! dp.online?
          stat = "offline"
        else
          alive = dp.is_alive? rescue false
          stat = (alive ? "alive" : "down")
        end
        dp_stats[dp_id] = stat
      end
      rr.meta[:data_provider_statuses]             = dp_stats
      rr.meta[:data_provider_statuses_last_update] = Time.now
    end
    true
  end

  # Clean the cached files of a list of users, for files
  # last accessed before the +before_date+ ; the task
  # is started in background, as it can be long.
  def self.process_command_clean_cache(command)
    user_ids    = command.user_ids.presence
    before_date = command.before_date.presence
    after_date  = command.after_date.presence
    types       = command.types.presence

    user_id_list = user_ids ? user_ids.split(",") : nil
    types_list   = types    ? types.split(",")    : nil

    CBRAIN.spawn_with_active_records(:admin, "Cache Cleanup") do
      syncs = SyncStatus.where( :remote_resource_id => RemoteResource.current_resource.id )
      syncs = syncs.where([ "sync_status.accessed_at < ?", before_date])          if before_date
      syncs = syncs.where([ "sync_status.accessed_at > ?", after_date])           if after_date
      syncs = syncs.joins(:userfile)                                              if user_id_list || types_list
      syncs = syncs.where( 'userfiles.user_id' => user_id_list )                  if user_id_list
      syncs = syncs.where( 'userfiles.type'    => types_list )                    if types_list

      syncs = syncs.all.to_a.shuffle
      syncs.each_with_index do |ss,i|
        userfile = ss.userfile
        Process.setproctitle "CacheCleanup ID=#{userfile.try :id} #{i+1}/#{syncs.size}"
        userfile.cache_erase rescue nil
        ss.delete rescue nil
      end
    end

    true
  end

  # This installs a pair of private/public SSH keys
  # for a user. The key pair has been created by another
  # CBRAIN app which sent this command to install a copy
  # of the files here.
  def self.process_command_push_ssh_keys(command)
    myself   = RemoteResource.current_resource

    # Command params
    priv_key = command.delete(:ssh_key_priv)
    pub_key  = command.delete(:ssh_key_pub)
    user_id  = command.requester_user_id
    user     = User.find(user_id)

    # To avoid sending back the info on the controls channel
    command.ssh_key_priv = "[FILTERED]"
    command.ssh_key_pub  = "[FILTERED]"

    # Install key files
    ssh_key  = user.ssh_key(ok_no_files: true)
    ssh_key.install_key_files(pub_key, priv_key)
    ssh_key.validate!

    # Log install date
    user.addlog("User SSH key installed on #{myself.name}")
    myself.addlog("User SSH key for #{user.login} installed")
    user.meta["ssh_key_install_date_#{myself.id}"] = Time.now

    true
  end

  # This remote command copies a set of files to
  # a destination DataProvider. At the end, a
  # Message is created with a summary of the
  # successes or failures.
  def self.process_command_copy_files(command)
    # Command params
    userfile_ids           = command.userfile_ids.split(",")
    dest_data_provider_id  = command.dest_data_provider_id
    user_id                = command.requester_user_id.presence || User.admin.id
    user                   = User.find(user_id)

    dest_dp = DataProvider.find(dest_data_provider_id)

    # Loop though the files and copy them
    CBRAIN.spawn_with_active_records(:admin, "Userfile Copy") do
      status = {} # message => count
      userfile_ids.each_with_index do |userfile_id,idx|
        userfile = Userfile.where(:id => userfile_id).first
        next unless userfile # doesn't exist? ignore
        Process.setproctitle "CopyFiles ID=#{userfile_id} #{idx+1}/#{userfile_ids.size}"
        message = "" # scope declaration
        begin
          copied = userfile.provider_copy_to_otherprovider(dest_dp)
          message = copied ? 'Copied' : 'Not copied (already exists?)'
        rescue => ex
          message = "Error copying: #{ex.message}"
        end
        status[message] ||= 0
        status[message]  += 1
      end
      message_type = (status.keys.size == 1 && status.keys.first == 'Copied') ? :notice : :error
      Message.send_message(user,
        { :message_type  => message_type,
          :header        => "File copying operation finished.",
          :variable_text => (status.map { |m,c| "#{c} x #{m}" }.join("\n")),
        }
      )
    end

    true
  end

  # Helper method to prepend 'source cbrain_bashrc;' to shell command.
  # The 'cbrain_bashrc' script is the one located in
  # the "/script" subdirectory under the remote resource's
  # RAILS root directory. Normally it's empty.
  def prepend_source_cbrain_bashrc(shell_command)
    cbrain_bashrc_path = self.ssh_control_rails_dir + "/script/cbrain_bashrc"
    return "source #{cbrain_bashrc_path.to_s.bash_escape}; #{shell_command}"
  end

end
