
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
# implementation requires Singularity 3.2 or better to
# be installed on the host, as well as a singularity
# container image that contains the basic Linux
# commands and the 'rsync' command too.
class SingSquashfsDataProvider < SshDataProvider

  # This is the basename of the singularity image
  # we use to access the squashfs filesystems; we
  # expect this image to be installed in the same
  # directory that contain them. Its minimum
  # requirements are that 1) basic UNIX commands
  # exist on it 2) the rsync command is installed
  # in it too.
  SINGULARITY_IMAGE_BASENAME = 'sing_squashfs.simg'

  # We use this to point to the directory INSIDE the container
  # were the root of the data is stored
  validates_presence_of :cloud_storage_client_path_start
  validates_format_of   :cloud_storage_client_path_start, :with => /\A\//

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
    "Singularity SquashFS"
  end

  def impl_is_alive? #:nodoc:
    return false unless super # basic SSH checks

    # Check we have one singularity image file
    remote_cmd  = "cd #{self.remote_dir.bash_escape};test -f #{SINGULARITY_IMAGE_BASENAME} && echo OK-Exists"
    text        = self.remote_bash_this(remote_cmd)
    # The following check will also make sure the remote shell is clean!
    return false unless text =~ /\AOK-Exists\s*\z/

    # Check we have at least one .squashfs file in the remote_dir
    sq_files = get_squashfs_basenames
    return false unless sq_files.present?

    # Check we have singularity version 3.2 or better
    remote_cmd = "singularity --version"
    text       = self.remote_bash_this(remote_cmd)
    return false unless text =~ /^(\d+)\.(\d+)/
    major,minor = Regexp.last_match[1,2].map(&:to_i)
    return false if  major  < 2
    return false if  major == 3 && minor < 2
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

    # It's IMPORTANT that the source be specified with a bare ':' in front.
    text = bash_this("#{rsync} -a -l --no-p --no-g --chmod=u=rwX,g=rX,o=r --delete #{self.rsync_excludes} :#{remote_shell_escape(remotefull)}#{sourceslash} #{shell_escape(localfull)} 2>&1")
    text.sub!(/Warning: Permanently added[^\n]+known hosts.\s*/i,"") # a common annoying warning
    cb_error "Error syncing userfile to local cache, rsync returned:\n#{text}" unless text.blank?
    unless File.exist?(localfull)
      cb_error "Error syncing userfile to local cache: no destination file found after rsync?\n" +
               "Make sure you are running rsync 3.0.6 or greater!"
    end
    true
  end

#    AttrList = [
#                  :name, :symbolic_type, :size, :permissions,
#                  :uid, :gid, :owner, :group,
#                  :atime, :mtime, :ctime,
#               ]


  def impl_provider_list_all(user=nil) #:nodoc:
    text       = remote_in_sing_stat_all(self.cloud_storage_client_path_start,".",true)
    file_infos = stat_reports_to_fileinfos(text)
    file_infos
  end

  def impl_provider_collection_index(userfile, directory = :all, allowed_types = :regular) #:nodoc:
    allowed_types = Array(allowed_types)

    # The behavior of the *collection_index methods is weird.
    basedir    = Pathname.new(self.cloud_storage_client_path_start)
    if directory == :all
      subdir     = userfile.name
      one_level  = false
    elsif directory == :top
      subdir     = userfile.name
      one_level  = true
    else
      subdir     = Pathname.new(userfile.name) + directory
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
    file_infos.reject! { |fi| fi.name == subdir.to_s } # we nee

    file_infos
  end

  def provider_full_path(userfile)
    Pathname.new(self.cloud_storage_client_path_start) + userfile.name
  end



  ########################################################
  # Unimplementable API methods
  ########################################################

  def impl_provider_readhandle(userfile, *args) #:nodoc:
    raise "Error: No streaming allowed for the DP."
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

  def get_squashfs_basenames(force = false) #:nodoc:
    @sq_files ||= self.meta[:squashfs_basenames] # cached_values

    if @sq_files.nil? || force
      remote_cmd  = "cd #{self.remote_dir.bash_escape} && ls -1 | grep -F .squashfs"
      text        = self.remote_bash_this(remote_cmd)
      lines       = text.split("\n")
      @sq_files   = lines.select { |l| l =~ /\A\S+\.squashfs\z/ }.sort
      self.meta[:squashfs_basenames] = @sq_files
    end

    @sq_files
  end

  def singularity_exec_prefix #:nodoc:
    sq_files     = get_squashfs_basenames
    overlay_opts = "--overlay " + sq_files.join(" --overlay ")
    "cd #{self.remote_dir.bash_escape} && singularity -s exec #{overlay_opts} #{SINGULARITY_IMAGE_BASENAME}"
  end

  def remote_rsync_command #:nodoc:
    "#{singularity_exec_prefix} rsync"
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
    ssh_opts = self.ssh_shared_options
    ssh      = "ssh -q -x #{ssh_opts}"
    rsync    = "rsync -e #{shell_escape(ssh)} --rsync-path=#{shell_escape(remote_rsync_command)}"
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
    com = "cd #{basedir.to_s.bash_escape};find #{subdir.to_s.bash_escape} #{max_depth} #{type_opt} -printf \"#{find_format}\""
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

# DEBUG
def remote_bash_this(com)
puts_red "REMOTE: #{com}"
super
end

# DEBUG
def bash_this(com)
puts_yellow "BASH: #{com}"
super
end

end
