
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
# files out of a single filesystem file. The
# implementation requires Singularity 3.2 or better to
# be installed on the host, as well as a singularity
# container image that contains the basic Linux
# commands and the 'rsync' command too.
#
# For the moment the DP is read-only. Allowing
# write access would require a mechanism in CBRAIN
# to prevent more than one singularity process to
# be accessing the mounted file at any one time.
#
# Bind mounts are performed using a command such as:
#
#   singularity shell -B filesystem.img:/my/mount/point:image-src=/inside/dir,ro sing_squashfs.simg
#
# where:
# 1- sing_squashfs.simg is a singularity image file,
# 2- filesystem.img is either a ext3 or squashfs filesystem,
# 3- /inside/dir is a path inside that filesystem,
# 4- /my/mount/point is a path where the data will be mounted under
# and which doesn't need to exist in sing_squashfs.simg
#
# This class hardcode the values for /my/mount/point to be "/cbrain"
# and /inside/dir to be "/". The value of the data provider
# attribute 'containerized_path' is used to narrow down wich part
# of the mounted filesystem is accessed by CBRAIN, and so normally
# should always start with '/cbrain' too.
#
# The attribute 'remote_dir' must be a full path to the location of
# the filesystem image 'filesystem.img' (even though it is not a 'dir').
# The singularity image file will be expected to be called 'sing_squashfs.simg'
# and be located in the same subdirectory as 'filesystem.img'.
class SingBindmountDataProvider < SshDataProvider

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # How long we cache the results of provider_list_all();
  # since this DP handles only static data, it could
  # be forever, really.
  #
  # TODO: Change this is the DP is ever made writable!
  BROWSE_CACHE_EXPIRATION = 2.months #:nodoc:

  # This is the basename of the singularity image
  # we use to access the remote filesystem; we
  # expect this image to be installed in the same
  # directory that contains it. Its minimum
  # requirements are that 1) basic UNIX commands
  # exist on it 2) the rsync command is installed
  # in it too.
  SINGULARITY_IMAGE_BASENAME = 'sing_squashfs.simg'

  # We use this to point to the directory INSIDE the container
  # were the root of the data is stored.
  validates_presence_of :containerized_path
  validates_format_of   :containerized_path, :with => /\A\/cbrain/

  # We can't write to this provider. This method
  # overrides the ActiveRecord attribute of the same name.
  def read_only #:nodoc:
    true
  end

  # We just ignore all changes to this attribute too.
  def read_only=(val) #:nodoc:
    val
  end

  # This returns the category of the data provider
  def self.pretty_category_name #:nodoc:
    "Singularity Bind Mount"
  end

  # This uses the new CBRAIN capability of registering
  # files at different levels.
  def has_browse_path_capabilities?
   true
  end

  def impl_is_alive? #:nodoc:
    check_remote_config!
  rescue
    false
  end

  # Raise an exception with a message indicating what is wrong with the config.
  # This method is not part of the official method API
  def check_remote_config! #:nodoc:
    # Check we have one singularity image file
    remote_cmd  = "cd #{self.real_remote_dir.to_s.bash_escape} && test -f #{SINGULARITY_IMAGE_BASENAME} && echo OK-Exists"
    text        = self.remote_bash_this(remote_cmd)
    # The following check will also make sure the remote shell is clean!
    cb_error "No installed singularity image #{SINGULARITY_IMAGE_BASENAME}, or remote shell is unclean" unless text =~ /\AOK-Exists\s*\z/

    # Check we have the remote filesystem file
    remote_cmd  = "test -f #{self.remote_dir.to_s.bash_escape} && echo OK-Exists"
    cb_error "Filesystem file '#{self.remote_dir}' not found" unless text =~ /\AOK-Exists\s*\z/

    # Check we have singularity version 3.7 or better
    remote_cmd = "singularity --version"
    text       = self.remote_bash_this(remote_cmd)
    cb_error "Can't find singularity version number on remote host" unless text =~ /^(singularity version )?(\d+)\.(\d+)/
    major,minor = Regexp.last_match[2,2].map(&:to_i)
    cb_error "singularity version number on remote host is less than 3.0" if major  < 3
    cb_error "singularity version number on remote host is less than 3.7" if major == 3 && minor < 7

    # Check that inside the container, the containerized path exists
    checkdir     = "test -d #{self.containerized_path.bash_escape} && echo OK-Exists"
    text         = remote_in_sing_bash_this(checkdir)
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
    text = bash_this("#{rsync} -a -l --no-g --chmod=u=rwX,g=rX,Dg+s,o=r --delete #{self.rsync_excludes} #{source_colon}#{source_escaped}#{sourceslash} #{shell_escape(localfull)} 2>&1")
    text.sub!(/Warning: Permanently added[^\n]+known hosts.\s*/i,"") # a common annoying warning
    cb_error "Error syncing userfile to local cache, rsync returned:\n#{text}" unless text.blank?
    unless File.exist?(localfull)
      cb_error "Error syncing userfile to local cache: no destination file found after rsync?\n" +
               "Make sure you are running rsync 3.0.6 or greater!"
    end
    true
  end

  # Returns (and caches for 6 months) the entries in the DP. +user+ is not used here.
  # Note that the DataProvider controller also caches this list in a YAML file in /tmp,
  # and it considers it valid for only one minute, so it will refresh that way more
  # often than our 6 months long caching here. The thing is, fetching the list from the
  # DP side is the real expensive operation, but also we don't expect the list to change
  # since this DP type is for static, read-only data.
  def impl_provider_list_all(user=nil, browse_path=nil) #:nodoc:
    cache_key  = "#{self.class}-#{self.id}-file_infos-#{browse_path}"

    file_infos = Rails.cache.fetch(cache_key, :expires_in => BROWSE_CACHE_EXPIRATION) do
      dir  = Pathname.new(self.containerized_path) + browse_path.to_s
      text = remote_in_sing_stat_all(dir,".",true)
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
    text       = remote_in_sing_stat_all(basedir, subdir, one_level, type_opt)
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

  def provider_full_path(userfile) #:nodoc:
    Pathname.new(self.containerized_path) + userfile.browse_name
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

  protected

  # Returns true if we have to use 'ssh' to
  # connect to the remote server. Returns false
  # when we can optimize requests by running
  # singularity locally. The local situation is
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

  def singularity_exec_prefix #:nodoc:
    "cd #{self.real_remote_dir.to_s.bash_escape} && singularity -s exec #{self.local_bind_opt} #{SINGULARITY_IMAGE_BASENAME}"
  end

  def local_bind_opt #:nodoc:
    "-B #{self.filesystem_image_basename.bash_escape}:/cbrain:image-src=/,ro"
  end

  def remote_rsync_command #:nodoc:
    "#{singularity_exec_prefix} rsync"
  end

  def real_remote_dir #:nodoc:
    Pathname.new(remote_dir()).parent
  end

  def filesystem_image_basename #:nodoc:
    Pathname.new(remote_dir()).basename.to_s
  end

  # Builds a prefix for a +rsync+ command, such as
  #
  #   "rsync -e 'ssh -x -o a=b -o c=d -p port --rsync-path='singularity exec overlay_or_bind_options_here img rsync' user@host'"
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

  def remote_in_sing_bash_this(com) #:nodoc:
    newcom = "#{singularity_exec_prefix} bash -c #{com.bash_escape}"
    remote_bash_this(newcom)
  end

  def remote_in_sing_stat_all(basedir, subdir, one_level = true, find_type = nil) #:nodoc:
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
    remote_in_sing_bash_this(com)
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
