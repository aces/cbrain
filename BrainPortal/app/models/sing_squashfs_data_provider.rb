
#
# CBRAIN Project
#
# Copyright (C) 2008-2019
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

# This class implements a Data Provider which fetches
# files out of one or several SquashFS files. The
# implementation requires Apptainer 1.1 or better to
# be installed on the host, as well as an Apptainer
# container image that contains the basic Linux
# commands and the 'rsync' command too.
class SingSquashfsDataProvider < SshDataProvider

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # How long we cache the results of provider_list_all();
  # since this DP handles only static data, it could
  # be forever, really.
  BROWSE_CACHE_EXPIRATION = 6.months #:nodoc:

  # This is the basename of the Apptainer image
  # we use to access the squashfs filesystems; we
  # expect this image to be installed in the same
  # directory that contain them. Its minimum
  # requirements are that 1) basic UNIX commands
  # exist on it 2) the rsync command is installed
  # in it too.
  APPTAINER_IMAGE_BASENAME = 'sing_squashfs.simg'

  # We use this to point to the directory INSIDE the container
  # were the root of the data is stored
  validates_presence_of :containerized_path
  validates_format_of   :containerized_path, :with => /\A\//

  # We can't write to this provider. This method
  # overrides the ActiveRecord attribute of the same name.
  def read_only #:nodoc:
    true
  end

  # Returns true: forces this DP type to be read-only.
  def read_only? #:nodoc:
    true
  end

  # We just ignore all changes to this attribute too.
  def read_only=(val) #:nodoc:
    val
  end

  # This returns the category of the data provider
  def self.pretty_category_name #:nodoc:
    "Single Level"
  end

  def impl_is_alive? #:nodoc:
    return false unless super # basic SSH checks
    check_remote_config!
  rescue
    false
  end

  # Check we have Apptainer 1.1 or better
  def apptainer_executable_name
    return @_tool if @_tool # cached name of executable

    remote_cmd = "( apptainer --version 2>/dev/null || singularity --version 2>/dev/null )"
    # Apptainer is preferable so it comes first in the command
    # also works if an old Singularity
    # todo loop over list of several candidate executables
    text       = self.remote_bash_this(remote_cmd)
    cb_error "Can't find Apptainer version number on remote host" unless text =~ /^((singularity|apptainer) version )?(\d+)\.(\d+)/
    _, _, @_tool, major, minor = Regexp.last_match.to_a
    major = major.to_i
    minor = minor.to_i
    if @_tool == 'singularity'
      cb_error "Singularity version number on remote host is less than 3.7" if major  < 3 || (major == 3 && minor < 7)
    else # tool == 'apptainer'
      cb_error "Apptainer version number on remote host is less than 1.1"   if major  < 1 || (major == 1 && minor < 1)
    end

    return @_tool

  end



  # Raise an exception with a message indicating what is wrong with the config.
  # This method is not part of the official method API
  def check_remote_config! #:nodoc:
    # Check we have one Apptainer image file
    remote_cmd  = "cd #{self.remote_dir.bash_escape};test -f #{APPTAINER_IMAGE_BASENAME} && echo OK-Exists"
    text        = self.remote_bash_this(remote_cmd)
    # The following check will also make sure the remote shell is clean!
    cb_error "No installed Apptainer image #{APPTAINER_IMAGE_BASENAME}, or remote shell is unclean" unless text =~ /\AOK-Exists\s*\z/

    # Check we have at least one .squashfs file in the remote_dir
    sq_files = get_squashfs_basenames
    cb_error "No .squashfs files found" unless sq_files.present?
    # Check that inside the container
    all_sq_files = @sq_files
    @sq_files    = [ @sq_files.first ] # To speed up check, use only the first squashfs file
    checkdir     = "test -d #{self.containerized_path.bash_escape} && echo OK-Exists"
    text         = remote_in_apptainer_bash_this(checkdir)
    @sq_files    = all_sq_files # return it to proper full list
    cb_error "No path '#{self.containerized_path}' inside container" unless text =~ /\AOK-Exists\s*\z/

    # Well, we passed all the tests
    true
  end

  def impl_sync_to_cache(userfile) #:nodoc:
    localfull  = cache_full_path(userfile)
    remotefull = provider_full_path(userfile)

    mkdir_cache_subdirs(userfile)
    if userfile.is_a?(FileCollection)
      Dir.mkdir(localfull) unless File.directory?(localfull)
      sourceslash="/"
    end

    rsync = rsync_over_ssh_prefix

    # When using ssh, It's IMPORTANT that the source be specified with a bare ':' in front.
    source_colon   = provider_is_remote ? ":" : "localhost:"
    # If our rsync is running remotely, we need to escape the source twice.
    source_escaped = provider_is_remote ? remote_shell_escape(remotefull) : remotefull.to_s.bash_escape
    # As of rsync 3.1.2, rsync does the escaping of the remote path properly itself
    source_escaped = remotefull.to_s.bash_escape if self.class.local_rsync_protects_args?
    # We need the SSH agent even when doing local transfers
    CBRAIN.with_unlocked_agent

    text = bash_this("#{rsync} -a -l --no-g --chmod=u=rwX,g=rX,Dg+s,o=r --delete #{self.rsync_excludes} #{source_colon}#{source_escaped}#{sourceslash} #{shell_escape(localfull)} 2>&1")
    cb_error "Error syncing userfile ##{userfile.id} to local cache, rsync returned:\n#{text}" unless text.blank?
    unless File.exist?(localfull)
      cb_error "Error syncing userfile ##{userfile.id} to local cache: no destination file found after rsync?\n" +
               "Make sure you are running rsync 3.0.6 or greater!"
    end
    true
  end

  # Returns (and caches for 6 months) the entries in the DP. +user+ is not used here.
  # Note that the DataProvider controller also caches this list in fast living cache
  # and it considers it valid for only one minute, so it will refresh that way more
  # often than our 6 months long caching here. The thing is, fetching the list from the
  # DP side is the real expensive operation, but also we don't expect the list to change
  # since this DP type is for static, read-only data.
  def impl_provider_list_all(user=nil,browse_path=nil) #:nodoc:
    cache_key  = "#{self.class}-#{self.id}-file_infos"
    cache_key += "-#{browse_path.to_s}" if browse_path.present?

    file_infos = Rails.cache.fetch(cache_key, :expires_in => BROWSE_CACHE_EXPIRATION) do
      sourcedir  = Pathname.new(self.containerized_path)
      sourcedir += browse_path if browse_path.present?
      text = remote_in_apptainer_stat_all(sourcedir.to_s, "." ,true)
      stat_reports_to_fileinfos(text)
    end

    # Generally no entries mean an error in the config, so we don't want
    # to cache that empty array for one week.
    Rails.cache.delete(cache_key) if file_infos.blank?

    file_infos
  end

  def impl_provider_collection_index(userfile, directory = :all, allowed_types = :regular) #:nodoc:
    allowed_types = Array(allowed_types)

    # The behavior of the *collection_index methods is weird.
    basedir = Pathname.new(self.containerized_path)
    if directory == :all
      subdir     = userfile.browse_name
      one_level  = false
    elsif directory == :top
      subdir     = userfile.browse_name
      one_level  = true
    else
      subdir     = Pathname.new(userfile.browse_name) + directory
      one_level  = true
    end

    # This is an optimization fi filtering by normal files or
    # directories: the find command itself will limit its output
    type_opt   = allowed_types == [ :regular   ] ? "f" :
                 allowed_types == [ :directory ] ? "d" :
                 nil # we can still filter for other combinations on Ruby side
    text       = remote_in_apptainer_stat_all(basedir, subdir, one_level, type_opt)
    file_infos = stat_reports_to_fileinfos(text)

    # Apply more complex filters if necessary
    if allowed_types.size != 1 || allowed_types.first.to_s !~ /regular|directory/
      file_infos.select! { |fi| allowed_types.include? fi.symbolic_type } # other filtering
    end

    # We must always reject the one entry that represents the top of the
    # scanned area.
    if userfile.is_a?(FileCollection)
      file_infos.reject! { |fi| fi.name == subdir.to_s } # we nee
    end

    file_infos
  end

  def provider_full_path(userfile)
    Pathname.new(self.containerized_path) + userfile.name
  end



  ########################################################
  # Unimplementable API methods
  ########################################################

  # Note: this one COULD be provided with a bit of
  # coding. The implmentation is to run 'cat' inside the
  # container.
  def impl_provider_readhandle(userfile, *args) #:nodoc:
    raise "Error: Not Yet Implemented."
  end

  def impl_sync_to_provider(userfile) #:nodoc:
    raise "Error: No this provider type is read-only."
  end

  def impl_provider_erase(userfile) #:nodoc:
    raise "Error: No this provider type is read-only."
  end

  def impl_provider_rename(userfile,newname) #:nodoc:
    raise "Error: No this provider type is read-only."
  end



  ########################################################
  # Internal support methods
  ########################################################

  public

  # Returns the full paths to the overlays
  def apptainer_overlays_full_paths #:nodoc:
    self.get_squashfs_basenames.map do |basename|
      Pathname.new(self.remote_dir) + basename
    end.map(&:to_s)
  end

  protected

  # Returns true if we have to use 'ssh' to
  # connect to the remote server. Returns false
  # when we can optimize requests by running
  # Apptainer locally. The local situation is
  # detected pretty much like in the Smart DP
  # module: if the hostname is the same as *remote_host*
  # or *alternate_host*, and if the *remote_dir* exists
  # locally.
  def provider_is_remote #:nodoc:
    return @provider_is_remote if ! @provider_is_remote.nil?
    dp_hostnames  = (self.remote_host || "")
                    .+(',')
                    .+(self.alternate_host || "")
                    .split(",")
                    .map(&:strip)
                    .map(&:presence)
                    .compact

    # Our test is biased so that we try local only if we have a local dir
    # and the hostname match.
    if dp_hostnames.include?(Socket.gethostname) && File.directory?(self.remote_dir)
      @provider_is_remote = false
    else
      @provider_is_remote = true # basically, anything else and we try through SSH
    end

    @provider_is_remote
  end

  def get_squashfs_basenames(force = false) #:nodoc:
    @sq_files ||= self.meta[:squashfs_basenames] # cached_values

    if @sq_files.blank? || force
      remote_cmd  = "cd #{self.remote_dir.bash_escape} && ls -1"
      text        = self.remote_bash_this(remote_cmd)
      lines       = text.split("\n")
      @sq_files   = lines.select { |l| l =~ /\A\S+\.(squashfs|sqs|sqfs)\z/ }.sort
      self.meta[:squashfs_basenames] = @sq_files
    end

    @sq_files
  end

  def apptainer_exec_prefix #:nodoc:
    sq_files     = get_squashfs_basenames
    overlay_opts = sq_files.map { |f| "--overlay=#{f.bash_escape}:ro" }.join(" ")
    "cd #{self.remote_dir.bash_escape} && #{apptainer_executable_name} -s exec #{overlay_opts} #{APPTAINER_IMAGE_BASENAME}"
  end

  def remote_rsync_command #:nodoc:
    "#{apptainer_exec_prefix} rsync"
  end

  # Builds a prefix for a +rsync+ command, such as
  #
  #   "rsync -e 'ssh -x -o a=b -o c=d -p port --rsync-path='singularity exec --overlay a.squashfs img rsync' user@host'"
  #
  # Note that this means that remote file specifications for
  # rsync MUST start with a bare ":" :
  #
  #   rsync -e 'ssh_options_here user_host'  :/remote/file  local/file
  def rsync_over_ssh_prefix
    rsync_dash_e = ""
    if provider_is_remote
      ssh_opts     = self.ssh_shared_options
      ssh          = "ssh -q -x #{ssh_opts}"
      rsync_dash_e = "-e #{ssh.bash_escape}"
    end
    rsync    = "rsync #{rsync_dash_e} --rsync-path=#{remote_rsync_command.bash_escape}"
    rsync
  end

  def remote_in_apptainer_bash_this(com) #:nodoc:
    newcom = "#{apptainer_exec_prefix} bash -c #{com.bash_escape}"
    remote_bash_this(newcom)
  end

  def remote_in_apptainer_stat_all(basedir, subdir, one_level = true, find_type = nil) #:nodoc:
    max_depth   = one_level ? "-maxdepth 1"        : ""
    type_opt    = find_type ? "-type #{find_type}" : ""
    # Linux 'stat' command formats:
    #   *   type ("directory", "symbolic link", "regular file")
    #   *   permission in octal
    #   *   size in bytes
    #   **  uid, username
    #   **  gid, groupname
    #   *** access, modification, change times
    #   *   name
    #stat_format = "E=%F,%s,%a,%u,%U,%g,%G,%X,%Y,%Y,%n"
    #com = "cd #{basedir.to_s.bash_escape};find #{subdir.to_s.bash_escape} #{max_depth} -exec stat --format \"#{stat_format}\" \"{}\" \";\""
    # Linux 'find' command format:
    find_format = "E=%y,%m,%s,%U,%u,%G,%g,%A@,%T@,%C@,%p\\n"
    com = "cd #{basedir.to_s.bash_escape} && find #{subdir.to_s.bash_escape} #{max_depth} #{type_opt} -printf \"#{find_format}\""
    remote_in_apptainer_bash_this(com)
  end

  # Given a text file report such as this:
  #   E=d,755,4096,61049,prioux,71057,prioux,1564600957.2234174250,1564073149.5080369580,1564073149.5080369580,./t
  #   E=d,755,4096,61049,prioux,71057,prioux,1564601000.4876934620,1564073149.5080369580,1564073149.5080369580,./t/a
  #   E=f,644,4,61049,prioux,71057,prioux,1564129579.1207208990,1564073205.0000000000,1564073254.9937541950,./t/a/f.txt
  # returns an array of FileInfo objects.
  def stat_reports_to_fileinfos(text) #:nodoc:
    # Maps find format and stat format to FileInfo convention
    type_map = {
       "E=directory"     => :directory, # stat command, not used anymore
       "E=symbolic link" => :symlink,   # stat command, not used anymore
       "E=regular file"  => :regular,   # stat command, not used anymore
       "E=d"             => :directory, # find command
       "E=l"             => :symlink,   # find command
       "E=-"             => :regular,   # find command ?
       "E=f"             => :regular,   # find command
    }

    file_infos = text.split("\n").map do |comma_line|
      next nil unless comma_line =~ /\AE=/
      type,perm,size,uid,username,gid,groupname,atime,mtime,ctime,name = comma_line.split ","
      next nil if name.blank?
      next nil if name == '.'
      FileInfo.new(
        :name          => name.sub(/\A.\//,""),
        :symbolic_type => type_map[type] || 'unknown',
        :permissions   => perm.to_i(8),
        :size          => size.to_i,
        :uid           => uid.to_i,
        :gid           => gid.to_i,
        :owner         => username,
        :group         => groupname,
        :atime         => atime.to_i,
        :mtime         => mtime.to_i,
        :ctime         => ctime.to_i,
      )
    end

    file_infos.compact
  end

  # Unlike the superclass, we
  # here can switch between remote
  # and local mode.
  def remote_bash_this(com) #:nodoc:
    #puts_red "REMOTE: #{com}" # DEBUG
    if provider_is_remote
      super
    else
      bash_this(com)
    end
  end

  # DEBUG
  def bash_this(com) #:nodoc:
    #puts_yellow "BASH: #{com}" # DEBUG
    super
  end

end
