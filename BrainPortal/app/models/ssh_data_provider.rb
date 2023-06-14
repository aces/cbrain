
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

#
# This class provides an implementation for a data provider
# where the remote files are accessed through +ssh+ and +rsync+.
# The provider's files are stored in a flat directory, one
# level deep, directly specified by the object's +remote_dir+
# attribute. The file "hello" is thus stored in a path like this:
#
#     /remote_dir/hello
#
# For the list of API methods, see the DataProvider superclass.
#
class SshDataProvider < DataProvider

  include SshDataProviderBase

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # This returns the category of the data provider
  def self.pretty_category_name #:nodoc:
    "Single Level"
  end

  def impl_is_alive? #:nodoc:
    return false unless self.master.is_alive?
    remote_cmd = "test -d #{self.remote_dir.bash_escape} && echo OK-Dir 2>&1"
    text = self.remote_bash_this(remote_cmd)
    return(text =~ /OK-Dir/ ? true : false)
  rescue
    false
  end

  # Please make sure that subclasses that are not
  # browsable resets this value to false.
  def is_browsable?(by_user = nil) #:nodoc:
    return true if by_user.blank? || self.meta[:browse_gid].blank?
    return true if by_user.is_a?(AdminUser) || by_user.id == self.user_id
    by_user.is_member_of_group(self.meta[:browse_gid].to_i)
  end

  def allow_file_owner_change? #:nodoc:
    true # some subclasses reset this to false
  end

  def content_storage_shared_between_users? #:nodoc:
    true # this class stores all in a flat directory; some subclasses reset this to false
  end

  def impl_sync_to_cache(userfile) #:nodoc:
    localfull   = cache_full_path(userfile)
    remotefull  = provider_full_path(userfile)
    sourceslash = ""

    mkdir_cache_subdirs(userfile)
    if userfile.is_a?(FileCollection)
      Dir.mkdir(localfull) unless File.directory?(localfull)
      sourceslash="/"
    end

    rsync = rsync_over_ssh_prefix(userfile.user, userfile)

    # Double escaping for old rsyncs
    source_escaped = remote_shell_escape(remotefull)
    # As of rsync 3.1.2, rsync does the escaping of the remote path properly itself
    source_escaped = remotefull.to_s.bash_escape if self.class.local_rsync_protects_args?

    # It's IMPORTANT that the source be specified with a bare ':' in front.
    text = bash_this("#{rsync} -a -l --no-g --chmod=u=rwX,g=rX,Dg+s,o=r --delete #{self.rsync_excludes} :#{source_escaped}#{sourceslash} #{shell_escape(localfull)} 2>&1")
    cb_error "Error syncing userfile ##{userfile.id} to local cache, rsync returned:\n#{text}" unless text.blank?
    unless File.exist?(localfull)
      cb_error "Error syncing userfile ##{userfile.id} to local cache: no destination file found after rsync?\n" +
               "Make sure you are running rsync 3.0.6 or greater!"
    end
    true
  end

  def impl_sync_to_provider(userfile) #:nodoc:
    localfull   = cache_full_path(userfile)
    remotefull  = provider_full_path(userfile)
    cb_error "Error: file #{localfull} does not exist in local cache!" unless File.exist?(localfull)

    sourceslash = userfile.is_a?(FileCollection) ? "/" : ""
    rsync       = rsync_over_ssh_prefix(userfile.user, userfile)

    # Double escaping for old rsyncs
    dest_escaped = remote_shell_escape(remotefull)
    # As of rsync 3.1.2, rsync does the escaping of the remote path properly itself
    dest_escaped = remotefull.to_s.bash_escape if self.class.local_rsync_protects_args?

    # It's IMPORTANT that the destination be specified with a bare ':' in front.
    text = bash_this("#{rsync} -a -l --no-g --chmod=u=rwX,g=rX,Dg+s,o=r --delete #{self.rsync_excludes} #{shell_escape(localfull)}#{sourceslash} :#{dest_escaped} 2>&1")
    text.sub!(/Warning: Permanently added[^\n]+known hosts.\s*/i,"") # a common annoying warning
    cb_error "Error syncing userfile ##{userfile.id} to data provider, rsync returned:\n#{text}" unless text.blank?
    unless self.provider_file_exists?(userfile).to_s =~ /file|dir/
      cb_error "Error syncing userfile ##{userfile.id} to data provider: no destination file found after rsync?\n" +
               "Make sure you are running rsync 3.0.6 or greater!\n"
    end
    true
  end

  # Not an official API method; returns :file or :dir if the
  # the userfile's content exists on the provider side.
  # Returns :absent if no file or directory could be found
  # on the provider side.
  #
  # Careful! This returns :error if there is a DP connection error
  # even if the file exists!
  def provider_file_exists?(userfile) #:nodoc:
    remotefull  = provider_full_path(userfile).to_s
    check_cmd = "test -d #{remotefull.bash_escape} && echo dirExists; test -f #{remotefull.bash_escape} && echo fileExists; test ! -e #{remotefull.bash_escape} && echo absentExists"
    text = self.remote_bash_this(check_cmd, userfile.user, userfile)
    if text.present? && text =~ /(dir|file|absent)Exists/
      return Regexp.last_match[1].to_sym
    end
    :error
  rescue
    :error
  end

  def impl_provider_erase(userfile) #:nodoc:
    full     = provider_full_path(userfile)
    erase_cmd = "/bin/rm -rf #{full.to_s.bash_escape} >/dev/null 2>&1"
    remote_bash_this(erase_cmd, userfile.user, userfile)
    true
  end

  def impl_provider_rename(userfile,newname) #:nodoc:
    oldpath   = provider_full_path(userfile)
    remotedir = oldpath.parent
    newpath   = remotedir + newname

    oldpath   = oldpath.to_s
    newpath   = newpath.to_s

    self.master(userfile.user, userfile) # triggers unlocking the agent
    net_sftp(userfile.user, userfile) do |sftp|
      dest_exists = sftp.lstat!(newpath) rescue nil
      return false if dest_exists # means file exists already
      begin
        sftp.rename!(oldpath,newpath)
        return true
      rescue => ex
        return false
      end
    end
    false
  end

  def impl_provider_readhandle(userfile, rel_path = ".", &block) #:nodoc:
    full_path = provider_full_path(userfile) + rel_path
    cb_error "Error: read handle cannot be provided for non-file." unless userfile.is_a?(SingleFile)
    IO.popen("ssh #{ssh_shared_options(userfile.user, userfile)} cat #{remote_shell_escape(full_path)}","r") do |fh|
      yield(fh)
    end
  end

  def impl_provider_list_all(user=nil,browse_path=nil) #:nodoc:
    self.remote_dir_entries(self.browse_remote_dir(user), user)
  end

  # Allows us to browse a remote directory that changes based on the user.
  def browse_remote_dir(user=nil) #:nodoc:
    self.remote_dir
  end

  def impl_provider_collection_index(userfile, directory = :all, allowed_types = :regular) #:nodoc:
    list = []

    if allowed_types.is_a? Array
      types = allowed_types.dup
    else
      types = [allowed_types]
    end

    types.map!(&:to_sym)

    base_dir = "/"
    self.master(userfile.user, userfile) # triggers unlocking the agent
    net_sftp(userfile.user, userfile) do |sftp|
      entries = []
      if userfile.is_a? FileCollection
        if directory == :all
          entries = sftp.dir.glob(provider_full_path(userfile).to_s, "**/*")
        else
          directory = "." if directory == :top
          base_dir = "/" + directory + "/"
          base_dir.gsub!(/\/\/+/, "/")
          base_dir.gsub!(/\/\.\//, "/")
          entries = sftp.dir.entries(provider_full_path(userfile).to_s + base_dir ).reject{ |e| e.name =~ /^\./}.inject([]) { |result, e| result << e }
        end
      else
        request = sftp.stat(provider_full_path(userfile)) do |response|
          attr = response[:attrs]
          entry = Net::SFTP::Protocol::V01::Name.new(userfile.name,userfile.name,attr)
          entries << entry
        end
        request.wait
      end
      attlist = [ 'symbolic_type', 'size', 'permissions',
                  'uid',  'gid',  'owner', 'group',
                  'atime', 'ctime', 'mtime' ]
      entries.each do |entry|
        attributes = entry.attributes
        type = attributes.symbolic_type
        next unless types.include?(type)
        #next if entry.name == "." || entry.name == ".."
        next if is_excluded?(entry.name) # in DataProvider

        fileinfo               = FileInfo.new
        if userfile.is_a?(SingleFile)
          fileinfo.name          = userfile.name
        else
          fileinfo.name          = "#{userfile.name}#{base_dir}#{entry.name}"
        end

        bad_attributes = []
        attlist.each do |meth|
          begin
            val = attributes.send(meth)
            fileinfo.send("#{meth}=", val)
          rescue
            # puts "Method #{meth} not supported: #{e.message}"
            bad_attributes << meth
          end
        end
        attlist -= bad_attributes unless bad_attributes.empty?

        list << fileinfo
      end
    end
    list.sort! { |a,b| a.name <=> b.name }
    list
  end

  # Returns the full path to the content of +userfile+ on
  # the data provider's side. This is to be overridden
  # by subclasses where files are stored differently
  # on the provider's side.
  def provider_full_path(userfile)
    basename = userfile.name
    Pathname.new(remote_dir) + basename
  end

  def impl_provider_report #:nodoc:
    issues       = []
    remote_files = self.remote_dir_entries(self.remote_dir, self.user).map(&:name)

    # Make sure all registered files exist
    self.userfiles.where("name NOT IN (?)", remote_files.empty? ? [''] : remote_files).each do |miss|
      issues << {
        :type        => :missing,
        :message     => "Userfile '#{miss.name}'",
        :severity    => :major,
        :action      => :destroy,
        :userfile_id => miss.id,
        :user_id     => miss.user_id
      }
    end

    # Look for unregistered files
    remote_files.select { |u| ! self.userfiles.where(:name => u).exists? }.each do |unreg|
      issues << {
        :type     => :unregistered,
        :message  => "File '#{unreg}'",
        :severity => :trivial,
        :user_id  => nil
      }
    end

    issues
  end

  def impl_provider_repair(issue) #:nodoc:
    raise "No automatic repair possible. Register or delete the file manually." if issue[:type] == :unregistered

    super(issue)
  end

  protected

  # Returns a list of all files in remote directory +dirname+, with all their
  # associated metadata; size, permissions, access times, owner, group, etc.
  def remote_dir_entries(dirname, user = nil, userfile = nil)
    list    = []
    attlist = [ 'symbolic_type', 'size', 'permissions',
                'uid',  'gid',  'owner', 'group',
                'atime', 'ctime', 'mtime' ]
    self.master(user, userfile) # triggers unlocking the agent
    net_sftp(user, userfile) do |sftp|
      sftp.dir.foreach(dirname) do |entry|
        attributes = entry.attributes
        type = attributes.symbolic_type
        next if type != :regular && type != :directory && type != :symlink
        next if entry.name == "." || entry.name == ".."
        next if is_excluded?(entry.name) # in DataProvider

        fileinfo               = FileInfo.new
        fileinfo.name          = entry.name

        bad_attributes = []
        attlist.each do |meth|
          begin
            val = attributes.send(meth)
            fileinfo.send("#{meth}=", val)
          rescue
            #puts "Method #{meth} not supported: #{e.message}"
            bad_attributes << meth
          end
        end
        attlist -= bad_attributes unless bad_attributes.empty?

        list << fileinfo
      end
    end

    list.sort! { |a,b| a.name <=> b.name }
    list
  end

end

