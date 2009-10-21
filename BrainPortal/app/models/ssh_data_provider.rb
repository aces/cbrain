
#
# CBRAIN Project
#
# $Id$
#

require 'rubygems'
require 'net/ssh'
require 'net/sftp'

#
# This class provides an implementation for a data provider
# where the remote files are accessed through +ssh+ and +rsync+.
# The provider's files are stored in a flat directory, one
# level deep, directly specified by the object's +remote_dir+
# attribute. The file "hello" is this stored in a path like this:
#
#     /remote_dir/hello
#
# For the list of API methods, see the DataProvider superclass.
#
class SshDataProvider < DataProvider

  Revision_info="$Id$"

  # A class to represent a remote file accessible through SFTP.
  # Most of the attributes here are compatible with
  #   Net::SFTP::Protocol::V01::Attributes
  class FileInfo
    attr_accessor :name, :symbolic_type, :size, :permissions,
                  :uid, :gid, :owner, :group,
                  :atime, :mtime, :ctime
  end

  def impl_is_alive? #:nodoc:
    ssh_opts = self.ssh_shared_options
    ssh_opts.sub!(/ConnectTimeout=\d+/,"ConnectTimeout=1")
    dir  = shell_escape(self.remote_dir)
    text = bash_this("ssh -x -n #{ssh_opts} test -d #{dir} '||' echo Fail-Dir 2>&1")
    return(text.blank? ? true : false);
  rescue
    false
  end

  # Please make sure that subclasses that are not
  # browsable resets this value to false.
  def is_browsable? #:nodoc:
    true
  end

  def impl_sync_to_cache(userfile) #:nodoc:
    basename    = userfile.name
    localfull   = cache_full_pathname(basename)
    remotefull  = remote_full_path(userfile)
    sourceslash = ""

    mkdir_cache_subdirs(basename)
    if userfile.is_a?(FileCollection)
      Dir.mkdir(localfull) unless File.directory?(localfull)
      sourceslash="/"
    end

    rsync = rsync_over_ssh_prefix
    text = bash_this("#{rsync} -a -L --delete :#{shell_escape(remotefull)}#{sourceslash} #{shell_escape(localfull)} 2>&1")
    text.sub!(/Warning: Permanently added[^\n]+known hosts.\s*/i,"")
    raise "Error syncing userfile to local cache: rsync returned: #{text}" unless text.blank?
    true
  end

  def impl_sync_to_provider(userfile) #:nodoc:
    basename    = userfile.name
    localfull   = cache_full_pathname(basename)
    remotefull  = remote_full_path(userfile)
    raise "Error: file #{localfull} does not exist in local cache!" unless File.exist?(localfull)

    sourceslash = userfile.is_a?(FileCollection) ? "/" : ""
    rsync = rsync_over_ssh_prefix
    text = bash_this("#{rsync} -a -L --delete #{shell_escape(localfull)}#{sourceslash} :#{shell_escape(remotefull)} 2>&1")
    text.sub!(/Warning: Permanently added[^\n]+known hosts.\s*/i,"")
    raise "Error syncing userfile to data provider: rsync returned: #{text}" unless text.blank?
    true
  end

  def impl_provider_erase(userfile) #:nodoc:
    full     = remote_full_path(userfile)
    ssh_opts = self.ssh_shared_options
    bash_this("ssh -x -n #{ssh_opts} \"bash -c '/bin/rm -rf #{full} >/dev/null 2>&1'\"")
    true
  end

  def impl_provider_rename(userfile,newname) #:nodoc:
    oldpath   = remote_full_path(userfile)
    remotedir = oldpath.parent
    newpath   = remotedir + newname

    oldpath   = oldpath.to_s
    newpath   = newpath.to_s

    Net::SFTP.start(remote_host,remote_user, :port => remote_port, :auth_methods => 'publickey') do |sftp|
      begin
        att = sftp.lstat!(newpath)
        return false # means file exists already
      end rescue
      begin
        sftp.rename!(oldpath,newpath)
        userfile.name = newname
        return true
      rescue
        return false
      end
    end
    false
  end

  def impl_provider_list_all #:nodoc:
    list = []
    Net::SFTP.start(remote_host,remote_user, :port => remote_port, :auth_methods => 'publickey') do |sftp|
      sftp.dir.foreach(remote_dir) do |entry|
        attributes = entry.attributes
        type = attributes.symbolic_type
        next if type != :regular && type != :directory && type != :symlink
        next if entry.name == "." || entry.name == ".."

        fileinfo               = FileInfo.new
        fileinfo.name          = entry.name

        attlist = [ 'symbolic_type', 'size', 'permissions',
                    'uid',  'gid',  'owner', 'group',
                    'atime', 'ctime', 'mtime' ]
        attlist.each do |meth|
          begin
            val = attributes.method(meth).call
            fileinfo.method("#{meth}=").call(val)
          rescue => e
            puts "Method #{meth} not supported: #{e.message}"
          end
        end

        list << fileinfo
      end
    end
    list.sort! { |a,b| a.name <=> b.name }
    list
  end

  # Returns the full path to the content of +userfile+ on
  # the data provider's side. This is to be overriden
  # by subclasses where files are stored differently
  # on the provider's side.
  def remote_full_path(userfile)
    basename = userfile.name
    Pathname.new(remote_dir) + basename
  end
  
  protected

  # Builds a prefix for a +rsync+ command, such as
  #
  #   "rsync -e 'ssh -x -o a=b -o c=d -p port user@host'"
  #
  # Note that this means that remote file specifications for
  # rsync MUST start with a bare ":" :
  #
  #   rsync -e 'ssh_options_here user_host'  :/remote/file  local/file
  def rsync_over_ssh_prefix
    ssh_opts = self.ssh_shared_options
    ssh      = "ssh -x #{ssh_opts}"
    rsync    = "rsync -e #{shell_escape(ssh)}"
    rsync
  end

  # Returns the necessary options to connect to a master SSH
  # command running in the background (which wil be started if
  # necessary).
  def ssh_shared_options
    master = SshTunnel.find_or_create(remote_user,remote_host,remote_port)
    master.start("DataProvider_#{self.name}") # does nothing is it's already started
    master.ssh_shared_options("auto") # ControlMaster=auto
  end
  
end

