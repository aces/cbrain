
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

  def impl_is_alive? #:nodoc:
     text = bash_this("ssh -x -n -o ConnectTimeout=1 -o StrictHostKeyChecking=false -o PasswordAuthentication=false -o KbdInteractiveAuthentication=no -o KbdInteractiveDevices=false #{self.option_port} #{self.ssh_user_host} true </dev/null 2>&1")
     return(text.blank? ? true : false);
  end

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
    text = bash_this("#{rsync} -a --delete #{ssh_user_host}:#{shell_escape(remotefull)}#{sourceslash} #{shell_escape(localfull)} 2>&1")
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
    text = bash_this("#{rsync} -a --delete #{shell_escape(localfull)}#{sourceslash} #{ssh_user_host}:#{shell_escape(remotefull)} 2>&1")
    raise "Error syncing userfile to data provider: rsync returned: #{text}" unless text.blank?
    true
  end

  def impl_provider_erase(userfile) #:nodoc:
    full     = remote_full_path(userfile)
    bash_this("ssh -x -n #{option_port} #{ssh_user_host} \"bash -c 'rm -rf #{full} >/dev/null 2>&1'\"")
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
        userfile.save
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
        next if type != :regular && type != :directory
        next if entry.name == "." || entry.name == ".."
        tuplet = [ entry.name, attributes.size, type, attributes.mtime ]
        list << tuplet
      end
    end
    list.sort! { |a,b| a[0] <=> b[0] }
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

  # Returns "remote_user@remote_host" properly escaped with single quotes to avoid code injection.
  def ssh_user_host
    shell_escape(self.remote_user) + "@" + shell_escape(self.remote_host)
  end

  # Returns "-o Port='1234'" properly escaped with single quotes to avoid code injection.
  # Suitable for ssh, sftp and scp, but not rsync.
  def option_port
    return "" if self.remote_port.blank? || self.remote_port == 0
    "-o Port=#{shell_escape(self.remote_port.to_s)}"
  end

  # Returns "--port '1234'" properly escaped with single quotes to avoid code injection.
  # Suitable for +rsync+.
  def dash_dash_port
    return "" if self.remote_port.blank? || self.remote_port == 0
    "--port #{shell_escape(self.remote_port.to_s)}"
  end

  # Returns ":'1234'" properly escaped with single quotes to avoid code injection.
  # Suitable for URL-like syntax on a command line, but not a pure URL.
  def colon_port
    return "" if self.remote_port.blank? || self.remote_port == 0
    ":#{shell_escape(self.remote_port.to_s)}"
  end

  # Builds a prefix for a +rsync+ command, such as
  #
  #   "rsync -e 'ssh -x'"
  #
  # or
  #
  #   "rsync -e 'ssh -x -p 1234'"
  def rsync_over_ssh_prefix
    prefix = "rsync"
    ssh    = "ssh -x -o PasswordAuthentication=no -o KbdInteractiveAuthentication=no -o KbdInteractiveDevices=false"
    unless self.remote_port.blank? || self.remote_port == 0
      ssh += " -p #{self.remote_port.to_s}"
    end
    prefix + " -e #{shell_escape(ssh)}"
  end
  
end

