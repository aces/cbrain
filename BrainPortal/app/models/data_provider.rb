
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

require 'fcntl'
require 'fileutils'
require 'pathname'
require 'socket'
require 'digest/md5'
require 'file_info'

#
# = Data Provider interface
#
# This abstract class describe an external 'data provider'
# for CBRAIN files.
#
# A data provider models a pair of endpoints: the *provider* side
# is where files are stored permanently, while the *cache* side
# is where files are stored in transit to being created and accessed.
# Typically, the *provider* side is a remote host or service, while
# the *cache* side is a filesystem local to the Rails application.
# Most programming tasks requires calling the methods on the *cache* side.
#
# Most API methods work on a Userfile object, which provides a
# name and a user ID for the object that are used to represent
# its content as a file. Since Userfiles have a data provider
# associated with them, this means that renaming a userfile +u+ would
# involve these steps:
#
#    data_provider_id = u.data_provider_id
#    data_provider    = DataProvider.find(data_provider_id)
#    data_provider.provider_rename(u,"newname")
#
# However, two shorthands can be used:
#
# * Use Rails's ability to link models directly:
#
#    u.data_provider.provider_rename(u,"newname")
#
# * Use the fact that the Userfile model has already been extended to provide access to the DataProvider methods directly:
#
#    u.provider_rename("newname")   # note that u is no longer supplied in argument
#
# == The API to write new files
#
# A typical scenario to *create* a new userfile and store its
# content (the string "ABC") on the provider looks like this:
#
#    u = SingleFile.new( :user_id => 2, :data_provider_id => 3, :name => "filename" )
#    u.cache_writehandle do |fh|
#      fh.write("ABC")
#    done
#    u.save
#
# Note that when the block provided to cache_writehandle() ends, a
# sync to the provider is automatically performed.
#
# Alternatively, if the content "ABC" of the file comes from another local
# file +localfile+, then the code can be rewritten as:
#
#    u = SingleFile.new( :user_id => 2, :data_provider_id => 3, :name => "filename" )
#    u.cache_copy_from_local_file(localfile)
#    u.save
#
# == The API to read files
#
# A typical scenario to *read* data from a userfile +u+ looks like this:
#
#    u.cache_readhandle do |fh|
#      data = fh.read
#    done
#
# Alternatively, if the data is to be sent to a local file +localfile+, then
# the code can be rewritten simply as:
#
#    u.cache_copy_to_local_file(localfile)
#
# == Handling FileCollections content
#
# The cache_readhandle() and cache_writehandle() methods can be used
# to access FileCollections, as long as a second argument is provided
# indicating the relative path of the file to be read from/written to.
# There is also a provider_readhandle() method to read from files on the
# provider side, though its use is not recommended except in cases where
# syncing to the cache is unfeasible (e.g. with particularly large
# datasets).
#
# The methods cache_copy_to_local_file() and cache_copy_from_local_file()
# will work perfectly well, assuming that the +localfile+ they are given
# in argument is itself a local subdirectory.
#
# When creating new FileCollections, the cache_prepare() method should be
# called once first, then the cache_full_path() can be used to obtain
# a full path to the subdirectory where the collection will be created
# (note that the subdirectory itself will not be created for you).
#
# = Here is the complete list of API methods:
#
# == Status or properties methods:
#
# * is_alive?
# * is_alive!
# * is_browsable?(by_user = nil)
# * is_fast_syncing?
# * allow_file_owner_change?
# * content_storage_shared_between_users?
#
# == Access restriction methods:
#
# * can_be_accessed_by?(user)  # user is a User object
# * has_owner_access?(user)    # user is a User object
#
# == Synchronization methods:
#
# * sync_to_cache(userfile)
# * sync_to_provider(userfile)
#
# Note that both of these are also present in the Userfile model.
#
# == Cache-side methods:
#
# * cache_prepare(userfile)
# * cache_full_path(userfile)
# * cache_readhandle(userfile, rel_path)
# * cache_writehandle(userfile, rel_path)
# * cache_copy_from_local_file(userfile, localfilename)
# * cache_copy_to_local_file(userfile, localfilename)
# * cache_erase(userfile)
# * cache_collection_index(userfile, directory, allowed_types)
#
# Note that all of these are also present in the Userfile model.
#
# == Provider-side methods:
#
# * provider_erase(userfile)
# * provider_rename(userfile, newname)
# * provider_move_to_otherprovider(userfile, otherprovider, options = {})
# * provider_copy_to_otherprovider(userfile, otherprovider, options = {})
# * provider_collection_index(userfile, directory, allowed_types)
# * provider_readhandle(userfile, rel_path)
# * provider_full_path(userfile)
# * provider_list_all(user=nil,browse_path=nil)
#
# Note that all of these except for provider_list_all() are
# also present in the Userfile model.
#
# = Aditional notes
#
# Most methods raise an exception if the provider's +online+ attribute is
# false, or if trying to perform some write operation and the provider's
# +read_only+ attribute is true.
#
# None of the methods issue a save() operation on the +userfile+
# they are given in argument; this means that after a successful
# provider_rename(), provider_move_to_otherprovider() or
# provider_copy_to_otherprovider(), the caller must call
# the save() method explicitly.
#
# = Implementations In Subclasses
#
# A proper implementation in a subclass must have the following
# methods defined:
#
# * impl_is_alive?
# * impl_sync_to_cache(userfile)
# * impl_sync_to_provider(userfile)
# * impl_provider_erase(userfile)
# * impl_provider_rename(userfile,newname)
# * impl_provider_list_all(user=nil,browse_path=nil)
# * impl_provider_collection_index(userfile, directory, allowed_types)
# * impl_provider_readhandle(userfile, rel_path)
#
# =Attributes:
# [*name*] A string representing a the name of the data provider.
# [*remote_user*] A string representing a user name to use to access the remote site of the provider.
# [*remote_host*] A string representing a the hostname of the data provider.
# [*remote_port*] An integer representing the port number of the data provider.
# [*remote_dir*] An string representing the directory of the data provider.
# [*online*] A boolean value set to whether or not the provider is online.
# [*read_only*] A boolean value set to whether or not the provider is read only.
# [*description*] Text with a description of the data provider.
#
# = Associations:
# *Belongs* *to*:
# * User
# * Group
class DataProvider < ApplicationRecord

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  include ResourceAccess
  include LicenseAgreements
  include NumericalSubdirTree
  include ConsistencyChecks

  cbrain_abstract_model! # objects of this class are not to be instantiated

  validates               :name,
                          :uniqueness        => true,
                          :presence          => true,
                          :identifier_format => true

  validates               :type,
                          subclass: { allow_blank: true },
                          presence: true

  validates_presence_of   :user_id, :group_id
  validates_inclusion_of  :read_only, :in => [true, false]

  validates_format_of     :remote_user, :with => /\A\w[\w\-\.]*\z/,
                          :message  => 'is invalid as only the following characters are valid: alphanumeric characters, _, -, and .',
                          :allow_blank => true

  validates_format_of     :remote_host, :with => /\A\w[\w\-\.]*\z/,
                          :message  => 'is invalid as only the following characters are valid: alphanumeric characters, _, -, and .',
                          :allow_blank => true

  validates_format_of     :remote_dir, :with => /\A[\w\-\.\=\+\/]*\z/,
                          :message  => 'is invalid as only paths with simple characters are valid: a-z, A-Z, 0-9, _, +, =, . and of course /',
                          :allow_blank => true

  validate                :owner_is_appropriate

  belongs_to              :user
  belongs_to              :group
  has_many                :userfiles, :dependent => :restrict_with_exception

  # Resource usage is kept forever even if data provider is destroyed.
  has_many                :resource_usage

  api_attr_visible        :name, :type, :user_id, :group_id, :online, :read_only, :description

  # This value is used to trigger DP cache wipes
  # in the validation code (see CbrainSystemChecks)
  # Instructions: when the caching system changes,
  # put a legal DateTime value here that is just
  # BEFORE the commit that implements the change,
  # then commit this file with the new caching system.
  # It's important that this value always be BEFORE
  # the date of the GIT commit that implements the
  # system change, so that DP cache wipes get triggered.
  # When the cache is wiped, the DateTime of the current
  # DataProvider commit will be written in DP_CACHE_ID_FILE
  # which means a later date than the one hardcoded below.
  DataProviderCache_RevNeeded = "2011-01-01 12:00:00 -0400"

  # Basenames for special files in caching system
  DP_CACHE_ID_FILE  = "DP_Cache_Rev.id"
  DP_CACHE_MD5_FILE = "DP_Cache_Key.md5"
  DP_CACHE_SYML     = "DP_Cache" # Name for the symlinks pointing to the DP cache

  #################################################################
  #      Official DataProvider API methods
  #      - Provider query/access methods -
  #################################################################

  # This method must not block, and must respond quickly.
  # Returns +true+ or +false+.
  def is_alive?
    return false unless self.online?
    return impl_is_alive? ? true : false
  end

  # Raises an exception if is_alive? is +false+, otherwise
  # it returns +true+.
  def is_alive!
    cb_error "Error: provider #{self.name} is not accessible right now." unless self.is_alive?
    true
  end

  # This method returns true if the provider is 'browsable', that is
  # you can call provider_list_all() without fear of an exception.
  # Most data providers are not browsable.
  def is_browsable?(by_user = nil)
    false
  end

  # This predicate returns whether syncing from the current provider
  # is considered a negligeable operation. e.g. if the provider is local to the portal.
  #
  # For the base DataProvider class this returns false. For subclasses, this method
  # should be redefined to return +true+ if the given DataProvider is fast-syncing.
  def is_fast_syncing?
    false
  end

  # This predicate returns true if the structure of the files
  # on the data provider side allow us to assign and reassign
  # the CBRAIN ownership of the registered files without problem.
  # Note that this is not related at all to the ownership restrictions
  # on the files on the provider's host.
  #
  # Some old data provider subclasses (such as *Vault*) used to
  # create subdirectories with the CBRAIN user's login name in
  # a component, which made re-assigning the file to another user
  # problematic. Modern DPs such as *EnCbrain* don't have this
  # problem, the files are stored in hashes subdirectories with
  # only the ID used for the component paths.
  def allow_file_owner_change?
    false
  end

  # This predicate returns +true+ if the content storage
  # of the data provider share files between users, meaning
  # that if a file named X belong to a user, no other user
  # can have a file named X too. Typically, this is the
  # same as as saying 'files are all in the same directory'.
  #
  # In such a case, it means the Userfile assumption that
  # two files with the same name can coexist on the
  # same DP if they belong to different users is FALSE.
  # Normally, the Userfile model is not so strict
  # (see the Userfile validation rule for names' uniqueness).
  # The value returned by this method is used by
  # another Userfile callback, flat_dir_dp_name_uniqueness().
  #
  # This true/false value of this method is to be redefined
  # in subclasses to trigger the proper Userfile behavior.
  def content_storage_shared_between_users?
    false
  end

  # Indicates if the data provider has the capability
  # to register/access files under a 'browse path', which
  # is a relative path "a/b/c" stored in each userfile
  # in the attribute 'browse_path'. This path is used to
  # build the full location of the userfile's content on
  # that DP. Most DPs do NOT support this capability.
  def has_browse_path_capabilities?
    false
  end



  #################################################################
  # Official Data API methods (work on userfiles)
  #            - Synchronization -
  #################################################################

  # Synchronizes the content of +userfile+ as stored
  # on the provider into the local cache.
  def sync_to_cache(userfile)
    cb_error "Error: provider #{self.name} is offline."      unless self.online?
    cb_error "Error: provider #{self.name} is not syncable." if     self.not_syncable?
    rr_allowed_syncing!("synchronize content from")
    SyncStatus.ready_to_copy_to_cache(userfile) do
      impl_sync_to_cache(userfile)
    end
  end

  # Synchronizes the content of +userfile+ from the
  # local cache back to the provider.
  def sync_to_provider(userfile)
    cb_error "Error: provider #{self.name} is offline."        unless self.online?
    cb_error "Error: provider #{self.name} is read_only."      if     self.read_only?
    cb_error "Error: provider #{self.name} is not syncable."   if     self.not_syncable?
    cb_error "Error: file #{userfile.name} is immutable."      if     userfile.immutable?
    rr_allowed_syncing!("synchronize content to")
    SyncStatus.ready_to_copy_to_dp(userfile) do
      impl_sync_to_provider(userfile)
    end
  end



  #################################################################
  # Official Data API methods (work on userfiles)
  #            - Cache Side Methods -
  #################################################################

  # Makes sure the local cache is properly configured
  # to receive the content for +userfile+; usually
  # this method is called before writing the content
  # for +userfile+ into the cached file or subdirectory.
  # Note that this method is already called for you
  # when invoking cache_writehandle(userfile).
  def cache_prepare(userfile)
    cb_error "Error: provider #{self.name} is offline."   unless self.online?
    cb_error "Error: provider #{self.name} is read_only." if     self.read_only?
    rr_allowed_syncing!("synchronize content to")
    SyncStatus.ready_to_modify_cache(userfile) do
      mkdir_cache_subdirs(userfile)
    end
    true
  end

  # Returns the full path to the file or subdirectory
  # where the cached content of +userfile+ is located.
  # The value returned is a Pathname object, so be careful
  # to call to_s() on it, when necessary.
  def cache_full_path(userfile)
    cache_full_pathname(userfile) # this is the internal private version with a REAL path to the REAL cache
  end

  # Executes a block on a filehandle open in +read+ mode for the
  # cached copy of the content of +userfile+; note
  # that this method automatically calls the synchronization
  # method sync_to_cache(userfile) before creating
  # and returning the filehandle.
  #
  #   content = nil
  #   provider.cache_readhandle(u) do |fh|
  #     content = fh.read
  #   end
  def cache_readhandle(userfile, rel_path = nil)
    cb_error "Error: provider #{self.name} is offline."                    unless self.online?
    cb_error "Error: cannot use relative path argument with a SingleFile." if     userfile.is_a?(SingleFile) && rel_path
    sync_to_cache(userfile)
    full_path = cache_full_path(userfile)
    if userfile.is_a?(FileCollection) && rel_path
      rel_path = Pathname.new(rel_path).cleanpath.to_s if rel_path.is_a?(String) || rel_path.is_a?(Pathname)
      cb_error "Unacceptable path going outside data model." if rel_path.to_s.present? && rel_path.to_s =~ /\A\.\.|\A\//
      full_path += rel_path
    end
    cb_error "Error: read handle cannot be provided for non-file."         unless File.file? full_path.to_s
    File.open(full_path,"r") do |fh|
      yield(fh)
    end
  end

  # Executes a *block* on a filehandle open in +write+ mode for the
  # cached copy of the content of +userfile+; note
  # that this method automatically calls the method
  # cache_prepare(userfile) before the block is executed,
  # and automatically calls the synchronization
  # method sync_to_provider(userfile) after the block is
  # executed.
  #
  #   content = "Hello"
  #   provider.cache_writehandle(u) do |fh|
  #     fh.write(content)
  #   end
  #
  # In the case where +userfile+ is not a simple file
  # but is instead a directory (e.g. it's a FileCollection),
  # no filehandle is provided to the block, but the rest
  # of the behavior is identical. Note that brand new
  # FileCollections will NOT have a directory yet created
  # for them, only the path leading TO the FileCollection will
  # be there.
  #
  #   provider.cache_writehandle(filecollection) do
  #     Dir.mkdir(filecollection.cache_full_path)
  #     File.open("#{filecollection.cache_full_path}/abcd","w") do |fh|
  #       fh.write "data"
  #     end
  #   end
  def cache_writehandle(userfile, rel_path = nil)
    cb_error "Error: provider #{self.name} is offline."                    unless self.online?
    cb_error "Error: provider #{self.name} is read_only."                  if     self.read_only?
    cb_error "Error: file #{userfile.name} is immutable."                  if     userfile.immutable?
    cb_error "Error: cannot use relative path argument with a SingleFile." if     userfile.is_a?(SingleFile) && rel_path
    rel_path = Pathname.new(rel_path).cleanpath.to_s if rel_path.is_a?(String) || rel_path.is_a?(Pathname)
    cb_error "Unacceptable path going outside data model." if rel_path.to_s.present? && rel_path.to_s =~ /\A\.\.|\A\//
    cache_prepare(userfile)
    localpath = cache_full_path(userfile)
    SyncStatus.ready_to_modify_cache(userfile) do
      if userfile.is_a?(FileCollection) && !rel_path
        yield
      else # a normal file, just crush it
        localpath += rel_path if rel_path
        File.open(localpath,"w:BINARY") do |fh|
          yield(fh)
        end
      end
    end
    sync_to_provider(userfile)
  end

  # This method provides a quick way to set the cache's file content
  # to an exact copy of +localpath+, a locally accessible file or directory.
  # The synchronization method +sync_to_provider+ will automatically
  # be called after the copy is performed.
  def cache_copy_from_local_file(userfile, localpath)
    localpath = localpath.to_s # in case we get a Pathname
    cb_error "Error: provider #{self.name} is offline."                                   unless self.online?
    cb_error "Error: provider #{self.name} is read_only."                                 if     self.read_only?
    cb_error "Error: file does not exist: '#{localpath}'."                                unless File.exists?(localpath)
    cb_error "Error: file #{userfile.name} is immutable."                                 if     userfile.immutable?
    cb_error "Error: incompatible directory '#{localpath}' given for a SingleFile."       if
        userfile.is_a?(SingleFile)     && File.directory?(localpath)
    cb_error "Error: incompatible normal file '#{localpath}' given for a FileCollection." if
        userfile.is_a?(FileCollection) && File.file?(localpath)
    dest = cache_full_path(userfile).to_s
    cache_prepare(userfile)
    SyncStatus.ready_to_modify_cache(userfile) do
      needslash=""
      if File.directory?(localpath)
        FileUtils.remove_entry(dest, true) if File.exists?(dest) && ! File.directory?(dest)
        Dir.mkdir(dest) unless File.directory?(dest)
        needslash="/"
      else
        FileUtils.remove_entry(dest, true) if File.exists?(dest) && File.directory?(dest)
      end
      rsyncout = bash_this("rsync -a -l --no-g --chmod=u=rwX,g=rX,Dg+s,o=r --delete #{self.rsync_excludes} #{shell_escape(localpath)}#{needslash} #{shell_escape(dest)} 2>&1")
      cb_error "Failed to rsync local file '#{localpath}' to cache file '#{dest}';\nrsync reported: #{rsyncout}" unless rsyncout.blank?
    end
    sync_to_provider(userfile)
  end

  # This method provides a quick way to copy the cache's file
  # to an exact copy +localfile+, a locally accessible file.
  # The synchronization method +sync_to_cache+ will automatically
  # be called before the copy is performed.
  #
  # Note that if +localpath+ is a path to an existing filesystem
  # entry, it will be crushed and replaced; this is true even if
  # +localpath+ if of a different type than the +userfile+, e.g.
  # if +userfile+ is a SingleFile and +localpath+ is a path to
  # a existing subdirectory /a/b/c/, then 'c' will be erased and
  # replaced by a file.
  def cache_copy_to_local_file(userfile,localpath)
    localpath = localpath.to_s # in case we get a Pathname
    cb_error "Error: provider #{self.name} is offline."   unless self.online?
    cb_error "Error: provider #{self.name} is read_only." if     self.read_only?
    sync_to_cache(userfile)
    source    = cache_full_path(userfile).to_s
    return true if source == localpath
    needslash=""
    if File.directory?(source)
      FileUtils.remove_entry(localpath, true) if File.exists?(localpath) && ! File.directory?(localpath)
      Dir.mkdir(localpath) unless File.directory?(localpath)
      needslash="/"
    else
      FileUtils.remove_entry(localpath, true) if File.exists?(localpath) && File.directory?(localpath)
    end
    rsyncout = bash_this("rsync -a -l --no-g --chmod=u=rwX,g=rX,Dg+s,o=r --delete #{self.rsync_excludes} #{shell_escape(source)}#{needslash} #{shell_escape(localpath)} 2>&1")
    cb_error "Failed to rsync cache file '#{source}' to local file '#{localpath}';\nrsync reported: #{rsyncout}" unless rsyncout.blank?
    true
  end

  # Deletes the cached copy of the content of +userfile+;
  # does not affect the real file on the provider side.
  def cache_erase(userfile)
    SyncStatus.ready_to_modify_cache(userfile,:destroy) do
      # The cache contains three more levels, try to clean them:
      #   "/CbrainCacheDir/01/23/45/basename"
      begin
        # Get the path for the cached file. It's important
        # to call cache_full_pathname() and NOT cache_full_path(), as
        # it must raise an exception when there is no caching in the provider!
        fullpath = cache_full_pathname(userfile)
        # 1- Remove the basename itself (it's a file or a subdir)
        #FileUtils.remove_entry(fullpath, true) rescue true
        # 2- Remove the last level of the cache, "45", if possible
        level2 = fullpath.parent
        # In case some dump programmer decided to change perms in the cache to
        # settings that don't allow the remove_entry() to work properly...
        #system "find", level2, "-type", "d", "!", "-perm", "-u=rwx", "-exec", "chmod", "u+rwx", "{}", ";" # exec ftw!
        # Erase it all
        FileUtils.remove_entry(level2,true) rescue true
        # 3- Remove the medium level of the cache, "23", if possible
        level1 = level2.parent
        Dir.rmdir(level1)
        # 4- Remove the top level of the cache, "01", if possible
        level0 = level1.parent
        Dir.rmdir(level0)
      rescue Errno::ENOENT, Errno::ENOTEMPTY
        # Nothing to do if we fail, as we are just trying to clean
        # up the cache structure from bottom to top
      end
    end
    true
  end

  # Provides information about the files associated with a Userfile entry
  # that has been synced to the cache. Returns an Array of FileInfo objects
  # representing the individual files.
  #
  # Though this method will function on SingleFile objects, it is primarily meant
  # to be used on FileCollections to gather information about the individual files
  # in the collection.
  def cache_collection_index(userfile, directory = :all, allowed_types = :regular)
    cb_error "Error: provider #{self.name} is offline."   unless self.online?
    cb_error "Error: userfile #{userfile.name} with ID #{userfile.id} is not cached." unless
        userfile.is_locally_cached?
    list = []

    directory = Pathname.new(directory).cleanpath.to_s if directory.is_a?(String) || directory.is_a?(Pathname)
    cb_error "Unacceptable path going outside data model." if directory =~ /\A\.\.|\A\//

    if allowed_types.is_a? Array
      types = allowed_types.dup
    else
      types = [allowed_types]
    end

    types.map!(&:to_sym)
    types << :file if types.delete(:regular)

    Dir.chdir(cache_full_path(userfile).parent) do
      if userfile.is_a? FileCollection
        if directory == :all
          entries = Dir.glob(userfile.name + "/**/*")
        else
          directory = "." if directory == :top
          base_dir = Pathname.new(userfile.name) + directory
          entries  = Dir.entries(base_dir.to_s).reject { |e| e =~ /^\./ }.map { |e| (base_dir + e).to_s }
        end
      else
        entries = [userfile.name]
      end
      attlist = [ 'symbolic_type', 'size', 'permissions',
                  'uid',  'gid',  'owner', 'group',
                  'atime', 'ctime', 'mtime' ]
      entries.each do |file_name|
        entry = File.lstat(file_name)
        type = entry.ftype.to_sym
        next unless types.include?(type)
        next if is_excluded?(file_name)

        fileinfo               = FileInfo.new
        fileinfo.name          = file_name

        bad_attributes = []
        attlist.each do |meth|
          begin
            if meth == 'symbolic_type'
              fileinfo.symbolic_type = entry.ftype.to_sym
              fileinfo.symbolic_type = :regular if fileinfo.symbolic_type == :file
            else
              val = entry.send(meth)
              fileinfo.send("#{meth}=", val)
            end
          rescue
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



  #################################################################
  # Official Data API methods (work on userfiles)
  #            - Provider Side Methods -
  #################################################################

  # Deletes the content of +userfile+ on the provider side.
  def provider_erase(userfile)
    cb_error "Error: provider #{self.name} is offline."        unless self.online?
    cb_error "Error: provider #{self.name} is read_only."      if     self.read_only?
    cb_error "Error: file #{userfile.name} is immutable."      if     userfile.immutable?
    rr_allowed_syncing!("erase content on")
    SyncStatus.ready_to_modify_dp(userfile) do
      impl_provider_erase(userfile)
    end
  end

  # Renames +userfile+ on the provider side.
  # This will also rename the name attribute IN the
  # userfile object. A check for name collision on the
  # provider is performed first. The method returns
  # true if the rename operation was successful.
  def provider_rename(userfile,newname)
    cb_error "Error: provider #{self.name} is offline."               unless self.online?
    cb_error "Error: provider #{self.name} is read_only."             if     self.read_only?
    cb_error "Error: userfile #{userfile.name} in an invalid state."  unless userfile.valid?
    cb_error "Error: file #{userfile.name} is immutable."             if     userfile.immutable?
    rr_allowed_syncing!("rename content on")
    return true if newname == userfile.name
    unless Userfile.is_legal_filename?(newname)
      userfile.errors.add(:name, "contains illegal characters.")
      return false
    end
    target_exists = self.userfiles
                        .where(
                          :name    => newname,
                          :user_id => userfile.user_id,
                        )
                        .first
    return false if target_exists
    cache_erase(userfile)
    SyncStatus.ready_to_modify_dp(userfile) do
      if impl_provider_rename(userfile,newname.to_s)
        userfile.name = newname
        userfile.save!
        true
      else
        userfile.errors.add(:name, "could not be changed on data provider.")
        false
      end
    end
  end

  # Move a +userfile+ from the current provider to +otherprovider+.
  # Returns true if no move was necessary, and false if anything was amiss.
  # Options supported are :name, :user_id, :group_id which are
  # going to be used for the destination file, and :crush_destination
  # that needs to be true if the destination file already exists
  # and you want to proceed with the move anyway.
  def provider_move_to_otherprovider(userfile, otherprovider, options = {})
    cb_error "Error: provider #{self.name} is offline."            unless self.online?
    cb_error "Error: provider #{self.name} is read_only."          if     self.read_only?
    cb_error "Error: provider #{otherprovider.name} is offline."   unless otherprovider.online?
    cb_error "Error: provider #{otherprovider.name} is read_only." if     otherprovider.read_only?
    cb_error "Error: file #{userfile.name} is immutable."          if     userfile.immutable?
    rr_allowed_syncing!("synchronize content from")
    rr_allowed_syncing!("synchronize content to", nil, otherprovider)
    dp_allows_copy!(otherprovider)

    new_name     = options[:name]     || userfile.name
    new_user_id  = options[:user_id]  || userfile.user_id
    new_group_id = options[:group_id] || userfile.group_id
    crush        = options[:crush_destination]

    return true  if     self.id == otherprovider.id
    return false unless Userfile.is_legal_filename?(new_name)
    return false unless userfile.id # must be a fully saved file

    # Check quota at destination
    DiskQuota.exceeded!(new_user_id, otherprovider.id)

    # Find existing destination, if any
    target_exists = Userfile.where(
                      :name             => new_name,
                      :data_provider_id => otherprovider.id,
                      :user_id          => new_user_id
                    ).first

    if target_exists
      return true  if target_exists.id == userfile.id  # Same !?! I feel like this is impossible.
      return false if ! crush
      return false if target_exists.class != userfile.class # must be of same class
      target_exists.destroy # ok, we destroy the destination
    end

    # Get path to cached copy on current provider
    sync_to_cache(userfile)
    currentcache = userfile.cache_full_path

    # check in case another parallel 'move' op has beaten us to the punch
    userfile.reload
    return true if userfile.data_provider_id == otherprovider.id

    # Because of all the back and forth assignments below,
    # we need a full copy of the source userfile's attributes
    orig_file = userfile.dup # not .clone, as of Rails 3.1.10

    # Copy content to other provider
    upload_succeeded = true
    begin
      userfile.data_provider_id = otherprovider.id
      userfile.name             = new_name
      userfile.user_id          = new_user_id
      userfile.group_id         = new_group_id
      userfile.save!
      otherprovider.cache_copy_from_local_file(userfile,currentcache) # this also uploads to DP
    rescue => ex
      upload_succeeded = false
      Message.send_internal_error_message(nil, "move to provider problem", ex)
    ensure # make sure we return its definition to the original so we can erase it
      userfile.data_provider_id = self.id            # temporarily set it all back
      userfile.name             = orig_file.name
      userfile.user_id          = orig_file.user_id
      userfile.group_id         = orig_file.group_id
      userfile.save!
    end

    return false if ! upload_succeeded

    # Erase on current provider (thus the 'ensure' above)
    provider_erase(userfile) rescue true # ignore errors

    # Register properly all the userfile info on new provider
    userfile.data_provider_id = otherprovider.id
    userfile.name             = new_name
    userfile.user_id          = new_user_id
    userfile.group_id         = new_group_id
    userfile.save!

    # Log the operation
    userfile.addlog("Moved from DataProvider '#{self.name}' to DataProvider '#{otherprovider.name}'.")
    userfile.addlog("Renamed from '#{orig_file.name}' to '#{userfile.name}'.")                      if orig_file.name != new_name
    userfile.addlog("Reassigned from owner '#{orig_file.user.login}' to '#{userfile.user.login}'.") if orig_file.user_id != new_user_id
    userfile.addlog("Reassigned from group '#{orig_file.group.name}' to '#{userfile.group.name}'.") if orig_file.group_id != new_group_id
    userfile.addlog("Crushed existing file '#{target_exists.name}' (ID #{target_exists.id}).") if target_exists

    # Record InSync on new provider.
    SyncStatus.ready_to_modify_cache(userfile, 'InSync') do
      true # dummy as it's already in cache, but adjusts the SyncStatus
    end

    true
  end

  # Copy a +userfile+ from the current provider to +otherprovider+.
  # Returns the new userfile if data was actually copied, true if
  # no copy was necessary, and false if anything was amiss.
  # Options supported are :name, :user_id, :group_id which are
  # going to be used for the new file, and :crush_destination
  # that needs to be true if the destination file already exists
  # and you want to proceed with the copy anyway.
  def provider_copy_to_otherprovider(userfile, otherprovider, options = {})
    cb_error "Error: provider #{self.name} is offline."            unless self.online?
    cb_error "Error: provider #{otherprovider.name} is offline."   unless otherprovider.online?
    cb_error "Error: provider #{otherprovider.name} is read_only." if     otherprovider.read_only?
    rr_allowed_syncing!("synchronize content from")
    rr_allowed_syncing!("synchronize content to", nil, otherprovider)
    dp_allows_copy!(otherprovider)

    new_name     = options[:name]     || userfile.name
    new_user_id  = options[:user_id]  || userfile.user_id
    new_group_id = options[:group_id] || userfile.group_id
    crush        = options[:crush_destination]

    return true  if     self.id == otherprovider.id
    return false unless Userfile.is_legal_filename?(new_name)
    return false unless userfile.id # must be a fully saved file

    # Check quota at destination
    DiskQuota.exceeded!(new_user_id, otherprovider.id)

    # Find existing destination, if any
    target_exists = Userfile.where(
                      :name             => new_name,
                      :data_provider_id => otherprovider.id,
                      :user_id          => new_user_id
                    ).first

    if target_exists
      return true  if target_exists.id == userfile.id  # Same !
      return false if ! crush
      return false if target_exists.class != userfile.class # must be of same class
    end

    # Prepare destination
    newfile = target_exists || userfile.dup # not .clone, as of Rails 3.1.10
    newfile.data_provider_id = otherprovider.id
    newfile.name             = new_name
    newfile.user_id          = new_user_id
    newfile.group_id         = new_group_id
    newfile.size             = nil # will be set after the first save()
    newfile.created_at       = Time.now      unless target_exists
    newfile.updated_at       = Time.now
    newfile.immutable        = false
    newfile.save

    # Trigger callbacks for tracking size changes
    newfile.size = userfile.size
    newfile.save

    # Get path to cached copy on current provider
    sync_to_cache(userfile)
    currentcache = userfile.cache_full_path

    # Copy content to other provider
    begin
      otherprovider.cache_copy_from_local_file(newfile,currentcache)
    rescue => ex
      #todo add log information?
      raise ex
      #return false
    end

    # Copy log
    old_log = target_exists ? "" : userfile.getlog
    action  = target_exists ? 'crushed' : 'copied'
    userfile.addlog("Content #{action} to '#{newfile.name}' (ID #{newfile.id}) on DataProvider '#{otherprovider.name}'.")
    newfile.addlog("Content #{action} from '#{userfile.name}' (ID #{userfile.id}) of DataProvider '#{self.name}'.")
    unless old_log.blank?
      newfile.addlog("---- Original log follows: ----")
      newfile.raw_append_log(old_log)
      newfile.addlog("---- Original log ends here ----")
    end

    return newfile
  end

  # This method provides a way for a client of the provider
  # to get a list of files on the provider's side, files
  # that are not necessarily yet registered as +userfiles+.
  #
  # When called, the method accesses the provider's side
  # and returns an array of objects. These objects should
  # respond to the following accessor methods that describe
  # a remote file:
  #
  # name:: the base filename
  # symbolic_type:: one of :regular, :symlink, :directory
  # size:: size of file in bytes
  # permissions:: an int interpreted in octal, e.g. 0640
  # uid::  numeric uid of owner
  # gid::  numeric gid of the file
  # owner:: string representation of uid, the owner's name
  # group:: string representation of gid, the group's name
  # mtime:: modification time (an int, since Epoch)
  # atime:: access time (an int, since Epoch)
  # ctime:: attribute change time (an int, since Epoch)
  #
  # These attributes match those of the class
  #     Net::SFTP::Protocol::V01::Attributes
  # except for name() which is new.
  #
  # Not all these attributes need to be filled in; nil
  # is often acceptable for some of them. The bare minimum
  # is probably the set 'name', 'type' and 'size' and 'mtime'.
  #
  # The optional user object passed in argument can be used
  # to restrict the list of files returned to only those
  # that match one of the user's properties (e.g. ownership
  # or file location).
  #
  # Note that not all data providers are meant to be browsable.
  def provider_list_all(user=nil, browse_path=nil)
    cb_error "Error: provider #{self.name} is offline."       unless self.online?
    cb_error "Error: provider #{self.name} is not browsable." unless self.is_browsable?
    if browse_path.present? && ! self.has_browse_path_capabilities?
      cb_error "Error: a browse path was used with provider #{self.name} but it does not support the feature."
    end
    rr_allowed_syncing!("list content from")
    impl_provider_list_all(user, browse_path)
  end

  # Provides information about the files associated with a Userfile entry
  # whose actual contents are still only located on a DataProvider (i.e. it has not
  # been synced to the local cache yet).
  # Though this method will function on SingleFile objects, it is primarily meant
  # to be used on FileCollections to gather information about the individual files
  # in the collection.
  #
  # *NOTE*: this method should gather its information WITHOUT doing a local sync.
  #
  # When called, the method accesses the provider's side
  # and returns an array of FileInfo objects.
  #
  # The argument "directory" can have a value that is:
  #    :all, which returns an array of all of the files in the collection
  #    :top, which returns only the files in the top level directory of the collection
  #    directory string, which returns only the files in the directory that is under the collection with that name
  #
  def provider_collection_index(userfile, directory = :all, allowed_types = :regular)
    cb_error "Error: provider #{self.name} is offline." unless self.online?
    rr_allowed_syncing!("fetch file content list from")
    directory = Pathname.new(directory).cleanpath.to_s if directory.is_a?(String) || directory.is_a?(Pathname)
    cb_error "Unacceptable path going outside data model." if directory =~ /\A\.\.|\A\//
    impl_provider_collection_index(userfile, directory, allowed_types)
  end

  # Opens a filehandle to the remote data file and supplies
  # it to the given block. THIS METHOD IS TO BE AVOIDED;
  # the proper methodology is to cache a file before accessing
  # it locally. This method is meant as a workaround for
  # exceptional situations when syncing is not welcome.
  def provider_readhandle(userfile, *args, &block)
    cb_error "Error: provider #{self.name} is offline." unless self.online?
    rr_allowed_syncing!("stream content from")
    if userfile.is_locally_synced?
      cache_readhandle(userfile, *args, &block)
    else
      impl_provider_readhandle(userfile, *args, &block)
    end
  end

  # This method does NOT necessarily make sense for
  # all providers. Typically, it should provide (for
  # informational purposes only) the 'remote' path
  # where the file is actually stored on the data
  # provider. If there is no such 'path', the
  # provider could return any string representation
  # it feels helpful. Remember, some provider don't
  # even store data in a "path" at all (e.g. Amazon S3).
  # So this string is often purely for informational purposes.
  def provider_full_path(userfile)
    raise "Error: method not yet implemented in subclass."
  end



  #################################################################
  # Utility Non-API
  #################################################################

  def self.pretty_type #:nodoc:
    self.to_s
  end

  # This is a method that will return category type for this data provider
  # in the case of this class (abstract) it will not be invoked.
  # Returning a nil is the convention that we'll use to HIDE a data provider class from the interface.
  # So we'll return nil if the data provider class is not appriopriate for the users to view.
  def self.pretty_category_name
    nil
  end

  # Returns the site this data provider belongs to.
  def site
    @site ||= self.user.site
  end

  # Returns the first line of the description.
  def short_description
    description = self.description || ""
    raise "Internal error: can't parse description!?!" unless description =~ /\A(.+\n?)/ # the . doesn't match \n
    header = Regexp.last_match[1].strip
    header
  end

  # Checks whether DP is alive, but hits the cache first if it's good
  def is_alive_with_caching?
    if self.alive_cached_valid?
      return self.meta[:alive_cached]
    else
      # real check, cache result
      alive = self.is_alive?
      self.meta[:alive_cached] = alive
      self.meta[:alive_cached_time] = Time.now.to_i
      return alive
    end
  end

  # This method checks whether cache is still good, lasts 1 minute
  def alive_cached_valid?
    valid = (Time.now.to_i - self.meta[:alive_cached_time] <= 60)
    # Check that the alive cache is actually a boolean
    if !(self.meta[:alive_cached] == true || self.meta[:alive_cached] == false)
      valid = false
    end
    valid
  rescue
    false
  end

  # Override the default for_api() method so that the resulting
  # list of attributes also contains some more pseudo-attributes
  # taken from the class properties.
  #
  #     is_browsable                         => true/false
  #     allow_file_owner_change              => true/false
  #     is_fast_syncing                      => true/false
  #     content_storage_shared_between_users => true/false
  def for_api
    super.merge(
      {
        'is_browsable'                         => self.is_browsable?                         ,
        'is_fast_syncing'                      => self.is_fast_syncing?                      ,
        'allow_file_owner_change'              => self.allow_file_owner_change?              ,
        'content_storage_shared_between_users' => self.content_storage_shared_between_users? ,
      }
    )
  end



  #################################################################
  # Model Callbacks
  #################################################################

  # This verifies that the user_id matches an Admin user.
  # For security reason, no data providers should by default
  # be owned by normal users.
  #
  # This method can be overrided in subclasses.
  def owner_is_appropriate #:nodoc:
    return true if User.where(:id => self.user_id).first.is_a?(AdminUser)
    self.errors.add(:user_id, 'must be an administrator')
    return false
  end

  #################################################################
  # Class-level cache-handling methods
  #################################################################

  # Returns a unique key for this Ruby process' cache. This key
  # is maintained in a file in the cache_rootdir(), and created
  # by a call to self.create_cache_md5() .
  # It is setup to be a MD5 checksum, 32 hex characters long.
  # Note that this key is also recorded in a RemoteResource
  # object during CBRAIN's validation steps, at launch time.
  def self.cache_md5
    return @@key if self.class_variable_defined?('@@key') && ! @@key.blank?

    # Try to read key from special file in cache root directory
    cache_root = self.cache_rootdir() # class method, not cached
    key_file = (cache_root + DP_CACHE_MD5_FILE).to_s
    if File.exist?(key_file)
      @@key = File.read(key_file)  # a MD5 string, 32 hex characters, + LF
      @@key.gsub!(/\W+/,"") unless @@key.blank?
      return @@key          unless @@key.blank?
    end
    nil
  end

  # Creates a persistent file in the cache directory to record
  # a MD5 token to uniquely identify it.
  def self.create_cache_md5
    cache_root = self.cache_rootdir() # class method, not cached
    key_file = (cache_root + DP_CACHE_MD5_FILE).to_s
    # Create a key. We MD5 the hostname, the cache root dir
    # and the time. This should be good enough. It will still
    # work even if the directory is moved about or the computer
    # renamed, as long as the key file is left there.
    keystring  = Socket.gethostname + "|" + cache_root.to_s + "|" + Time.now.to_i.to_s
    md5encoder = Digest::MD5.new
    @@key      = md5encoder.hexdigest(keystring).to_s
    # Try to write it back. If the file suddenly has appeared,
    # we ignore our own key and use THAT one instead (race condition).
    begin
      fd = IO.sysopen(key_file, Fcntl::O_WRONLY | Fcntl::O_EXCL | Fcntl::O_CREAT)
      fh = IO.open(fd)
      fh.syswrite("#{@@key}\n")
      fh.close
      return @@key
    rescue # Oh? Open write failed? Some other process has created it underneath us.
      if ! File.exist?(key_file)
        raise "Error: could not create a proper Data Provider Cache Key in file '#{key_file}'!"
      end
      sleep 2+rand(5) # make sure other process writing to it is done
      @@key = File.read(key_file)  # a MD5 string, 32 hex characters, + LF
      @@key.gsub!(/\W+/,"") unless @@key.blank?
      raise "Error: could not read a proper Data Provider Cache Key from file '#{key_file}'!" if @@key.blank?
      return @@key.presence
    end
  end

  # This method returns the revision DateTime of the last time
  # the caching system was initialized. If the revision
  # number is unknown, then a string value of "Unknown" is returned
  # and the method will immediately store the current revision
  # DateTime. The value is stored in a file at the top of the
  # caching system's directory structure.
  def self.cache_revision_of_last_init(force = nil)
    return DateTime.parse(@@cache_rev) if ! force && self.class_variable_defined?('@@cache_rev') && ! @@cache_rev.blank?

    # Check that the root seems OK
    cache_root = self.cache_rootdir() # class method, not cached
    self.this_is_a_proper_cache_dir!(cache_root, :for_remote_resource_id => RemoteResource.current_resource.id) # raises exception if bad dir

    # Try to read rev from special file in cache root directory
    rev_file = (cache_root + DP_CACHE_ID_FILE).to_s
    if ! force && File.exist?(rev_file)
      @@cache_rev = File.read(rev_file) rescue "" # a alphanumeric ID as ASCII
      @@cache_rev = "" if @@cache_rev.blank? || @@cache_rev !~ /\A\d\d\d\d-\d\d-\d\d/
      @@cache_rev.strip!
      return DateTime.parse(@@cache_rev) unless @@cache_rev.blank?
      File.unlink(rev_file) rescue true
    end

    # Let's use the current revision date/time then.
    self.revision_info.self_update
    @@cache_rev = "#{self.revision_info.date} #{self.revision_info.time}"

    # Try to write it back. If the file suddenly has appeared,
    # we ignore our own rev and use THAT one instead (race condition).
    begin
      if force
        fd = IO.sysopen(rev_file, Fcntl::O_WRONLY | Fcntl::O_CREAT)
      else
        fd = IO.sysopen(rev_file, Fcntl::O_WRONLY | Fcntl::O_EXCL | Fcntl::O_CREAT)
      end
      fh = IO.open(fd)
      fh.syswrite(@@cache_rev + "\n")
      fh.close
      return "Unknown" # String to indicate it WAS unknown.
    rescue # Oh? Open write failed? Some other process has created it underneath us.
      if ! File.exist?(rev_file)
        raise "Error: could not create a proper Data Provider Cache Revision DateTime in file '#{rev_file}' !"
      end
      sleep 2+rand(5) # make sure other process writing to it is done
      @@cache_rev = File.read(rev_file) rescue ""
      @@cache_rev = "" if @@cache_rev.blank? || @@cache_rev !~ /\A\d\d\d\d-\d\d-\d\d/
      @@cache_rev.strip!
      raise "Error: could not read a proper Data Provider Cache Revision Number from file '#{rev_file}' !" if @@cache_rev.blank?
      return "Unknown" # String to indicate it WAS unknown.
    end
  end

  # This method checks the given +cache_root+ to make
  # sure it looks like a proper cache directory. The
  # test succeeds if it contains the file DP_CACHE_ID_FILE
  # (meaning it seems to have been used as a cache
  # directory in the past) or if the directory is empty
  # and writable. An exception is raised otherwise.
  # +options+ can be used to specify extra checks to be made.
  # Available options are:
  #  [*local*] Check against the local filesystem, active by default.
  #  [*key*]   MD5 key to match if a DP_CACHE_MD5_FILE exists
  #            in +cache_root+. Only applied if checking the
  #            local filesystem.
  #  [*host*]  Host machine the check is made against. Allows
  #            checking for path conflicts with data providers.
  #            Defaults to the current machine's hostname if
  #            checking the local filesystem.
  def self.this_is_a_proper_cache_dir!(cache_root,options = {})
    cache_root             = cache_root.to_s
    check_local            = options.has_key?(:local) ? options[:local].presence : true
    for_remote_resource_id = options[:for_remote_resource_id].presence # this is the ID of the remote resource for cache_root
    check_key              = options[:key].presence
    cache_host             = options[:host].presence
    cache_host  ||= Socket.gethostname if check_local

    cb_error "Invalid blank DP cache directory configured." if cache_root.blank?
    cb_error "DP cache directory configured cannot be a system temp dir: '#{cache_root}'" if
      cache_root.to_s =~ /^(\/tmp|\/(var|usr|private|opt|net|lib|mnt|sys)\/tmp)/i

    cache_root_path = Pathname.new(cache_root)

    if cache_host

      # Check to see if the cache dir match the path of any known Data Provider
      conflict_dp = self.all
        .select do |dp|
          Pathname.new(dp.remote_dir || '').cleanpath == cache_root_path
        end
        .find do |dp|
          hosts  = (dp.alternate_host || "").split(',')
          hosts <<  dp.remote_host
          hosts.include? cache_host
        end
      cb_error "DP cache directory matches the root of data provider '#{conflict_dp.name}'" if conflict_dp

      # Check to see if the cache dir match the cache dir of any *other* known Remote Resource
      conflict_rr = RemoteResource.all.reject do |rr|
          rr.id == for_remote_resource_id ||  # comparison to nil is OK here
          rr.dp_cache_dir.blank? ||
          rr.ssh_control_host.blank?
        end
        .select do |rr|
          Pathname.new(rr.dp_cache_dir).cleanpath == cache_root_path &&
          rr.ssh_control_host == cache_host
        end
        .first
      cb_error "DP cache directory matches the cache directory of #{conflict_rr.pretty_type} Server '#{conflict_rr.name}'" if conflict_rr
    end

    return true unless check_local

    cb_error "DP cache directory doesn't exist: '#{cache_root}'" unless
      File.directory?(cache_root)
    cb_error "DP cache directory not accessible: '#{cache_root}'" unless
      File.readable?(cache_root) && File.writable?(cache_root)

    rev_file        = (cache_root_path + DP_CACHE_ID_FILE).to_s
    key_file        = (cache_root_path + DP_CACHE_MD5_FILE).to_s

    cb_error "DP cache directory already in use by another server" if
      check_key && File.exist?(key_file) && File.read(key_file).gsub(/\W+/,"") != check_key

    return true if File.exist?(rev_file)

    entries = Dir.entries(cache_root.to_s) rescue nil
    if entries.nil? # exception?
      cb_error "Cannot inspect content of DP cache directory '#{cache_root}' ?"
    end
    entries.reject! { |e| e == "." || e == ".." || e == ".DS_Store" || e == DP_CACHE_ID_FILE || e == DP_CACHE_MD5_FILE }
    if entries.size > 0
      maxshow = entries.size > 5 ? 5 : entries.size
      cb_error "It seems the configured DP cache directory '#{cache_root}' contains data!\n" +
               "Found these files: " + entries[0..(maxshow-1)].join(", ") + "\n"
    end

    return true
  end

  # Root directory for the DataProvider cache system of the current Rails app.
  #     "/path/to/CbrainCacheDir"
  # Will raise an exception if this has not been configured by the admin.
  # The path is stored in the attribute dp_cache_dir of the RemoteResource
  # (BrainPortal) object that describes the current rail app.
  def self.cache_rootdir
    cache_rootdir = RemoteResource.current_resource.dp_cache_dir
    cb_error "No cache directory for Data Providers configured!"  if cache_rootdir.blank?
    Pathname.new(cache_rootdir)
  end

  def self.rsync_ignore_patterns #:nodoc:
    @ig_patterns ||= RemoteResource.current_resource.dp_ignore_patterns || []
  end

  # This method removes from the cache all files
  # and directories that are spurious (that is, do not
  # correspond to actual userfiles in the DB). Unless
  # +do_id+ is true, no files are actually erased.
  # Always returns an array of strings for the subpaths that
  # are/were superfluous, each like "01/23/45".
  # This whole process can take some time, and is mostly used
  # only once, at boot time.
  def self.cleanup_leftover_cache_files(do_it=false, options={})
    rr_id = RemoteResource.current_resource.id
    Dir.chdir(self.cache_rootdir) do
      dirlist = []

      # The find command below has been tested on Linux and Mac OS X
      # It MUST generate exactly three levels deep so it can properly
      # infer the original file ID !
      IO.popen("find . -mindepth 3 -maxdepth 3 -type d -print","r") { |fh| dirlist = fh.readlines rescue [] }
      uids2path = {} # this is the main list of what to delete (preliminary)
      dirlist.each do |path|  # path should be  "./01/23/45\n"
        next unless path =~ /\A\.\/(\d+)\/(\d+)\/(\d+)\s*\z/ # make sure
        idstring = Regexp.last_match[1..3].join("")
        uids2path[idstring.to_i] = path.strip.sub(/\A\.\//,"") #  12345 => "01/23/45"
      end

      # Might as well clean spurious SyncStatus entries too.
      # These are the ones that say something's in the cache,
      # yet we couldn't find any files on disk.
      supposedly_in_cache      = SyncStatus.where( :remote_resource_id => rr_id, :status => [ 'InSync', 'CacheNewer' ] )
      supposedly_in_cache_uids = supposedly_in_cache.raw_first_column(:userfile_id)
      not_in_cache_uids        = supposedly_in_cache_uids - uids2path.keys
      supposedly_in_cache.where( :userfile_id => not_in_cache_uids ).destroy_all

      return [] if uids2path.empty?

      # We wipe from the cache some dirs for which no
      # userfile exists, or dirs for which the userfile exist
      # but has no known synchronization status.
      all_uids        = Userfile.where({}).raw_first_column(:id)
      all_synced_uids = SyncStatus.where( :remote_resource_id => rr_id ).raw_first_column(:userfile_id)
      keep_cache_uids = all_uids & all_synced_uids & uids2path.keys
      keep_cache_uids.each { |id| uids2path.delete(id) } # prune the list: leave only the paths to delete!

      return [] if uids2path.empty?

      # Erase entries on disk!
      if do_it
        maybe_spurious_parents={}
        uids2path.keys.sort.each_with_index do |id,i|  # 12345
          path = uids2path[id]                         # "01/23/45"
          Process.setproctitle "Cache Spurious PATH=#{path} #{i+1}/#{uids2path.size}" if options[:update_dollar_zero]
          system("chmod","-R","u+rwX",path)   # uppercase X affects only directories
          FileUtils.remove_entry(path, true) rescue true
          maybe_spurious_parents[path.sub(/\/\d+\z/,"")]      = 1  # "01/23"
          maybe_spurious_parents[path.sub(/\/\d+\/\d+\z/,"")] = 1  # "01"
        end
        maybe_spurious_parents.keys.sort { |a,b| b <=> a }.each { |parent| Dir.rmdir(parent) rescue true }
      end
      return uids2path.values
    end
  end

  # Updates the time stamp for important auxiliary directories and files
  # as workaround for HPC file deletion policies.
  #
  # Some Bourreaux systems are configured with disk allocations where files older than N days are erased automatically.
  # To prevent such system from deleting the top-level directories for the DP_Cache, and some cbrain-specific files,
  # the boot process should touch them to reset their timestamps.
  #
  # For a portal or bourreau:
  #
  # - the +DataProvider+ cache dir
  # - the +DP_Cache_Key.md5+ and
  # - +DP_Cache_Rev.id+ located in that cache dir
  #
  # For a bourreau:
  #
  # - the +gridshare+ dir
  # - the +DP_Cache+ symbolic link located in it.
  def self.system_touch
    myself       = RemoteResource.current_resource
    cache_dir    = myself.dp_cache_dir
    dp_cache_id  = File.join cache_dir, DataProvider::DP_CACHE_ID_FILE
    dp_cache_md5 = File.join cache_dir, DataProvider::DP_CACHE_MD5_FILE

    FileUtils.touch [cache_dir, dp_cache_id, dp_cache_md5], verbose: true, nocreate: true

    # touch only cache for Portal, for Bourreau touch gridshare
    return true unless myself.is_a? Bourreau

    gridshare_dir = myself.cms_shared_dir
    sym_path      = File.join gridshare_dir, DataProvider::DP_CACHE_SYML

    FileUtils.touch gridshare_dir, verbose: true, nocreate: true

    # update timestamp for a softlink rather than the folder it points to
    # note, --no-dereference works on major os but not all of them
    system("touch", "--no-dereference", sym_path)  # --no-create is implied, at least for Rocky and Ubuntu
  end

  #################################################################
  # Access restriction checking methods, using flags in meta-data.
  #################################################################

  # Returns true if RemoteResource +rr+ is allowed to access DataProvider +check_dp+
  # (which defaults to self). The information for this restriction is maintained
  # as a blacklist in the meta data store.
  def rr_allowed_syncing?(rr = RemoteResource.current_resource, check_dp = self)
    rr ||= RemoteResource.current_resource
    meta_key_disabled = "rr_no_sync_#{rr.id}"
    check_dp.meta[meta_key_disabled].blank?
  end

  # Works like rr_allowed_syncing? but raise an exception when the
  # sync operation is not allowed. The exception message can be
  # customized with the first argument.
  def rr_allowed_syncing!(server_does_what = "access the files of", rr = RemoteResource.current_resource, check_dp = self)
    rr ||= RemoteResource.current_resource
    cb_error "Error: server #{rr.name} cannot #{server_does_what} provider #{check_dp.name}." unless
      self.rr_allowed_syncing?(rr, check_dp)
  end

  # Returns true if the DataProvider is allowed to copy or move files to the
  # other DataProvider +other_dp+ .
  # The information for this restriction is maintained
  # as a blacklist in the meta data store.
  def dp_allows_copy?(other_dp)
    meta_key_disabled = "dp_no_copy_#{other_dp.id}"
    self.meta[meta_key_disabled].blank?
  end

  # Works like dp_allows_copy? but raises an exception if the
  # copy or move operation is not allowed.
  def dp_allows_copy!(other_dp)
    cb_error "Error: provider #{self.name} is not allowed to send data to provider #{other_dp.name}." unless
      self.dp_allows_copy?(other_dp)
  end



  #################################################################
  # Implementation-dependant method placeholders
  # All of these methods MUST be implemented in subclasses.
  #################################################################

  protected

  def impl_is_alive? #:nodoc:
    raise "Error: method not yet implemented in subclass."
  end

  def impl_sync_to_cache(userfile) #:nodoc:
    raise "Error: method not yet implemented in subclass."
  end

  def impl_sync_to_provider(userfile) #:nodoc:
    raise "Error: method not yet implemented in subclass."
  end

  def impl_provider_erase(userfile) #:nodoc:
    raise "Error: method not yet implemented in subclass."
  end

  def impl_provider_rename(userfile,newname) #:nodoc:
    raise "Error: method not yet implemented in subclass."
  end

  def impl_provider_list_all(user=nil, browse_path=nil) #:nodoc:
    raise "Error: method not yet implemented in subclass."
  end

  def impl_provider_collection_index(userfile, directory = :all, allowed_types = :regular) #:nodoc:
    raise "Error: method not yet implemented in subclass."
  end

  def impl_provider_readhandle(userfile, *args) #:nodoc:
    raise "Error: method not yet implemented in subclass."
  end

  #################################################################
  # Internal cache-handling methods
  #################################################################

  # Returns the same value as the class method of the same
  # name, but caches the path in the current object.
  def cache_rootdir #:nodoc:
    @cache_rootdir ||= self.class.cache_rootdir()
  end

  # Returns an array of two subdirectory levels where a file
  # is cached. These are two strings of two digits each. For
  # instance, for +hello+, the method returns [ "32", "98" ].
  # Although this method is mostly used internally by the
  # caching system, it can also be used by other data providers
  # which want to build similar directory trees.
  #
  # Note that unlike the other methods in the cache management
  # layer, this method only takes a basename, not a userfile,
  # in argument.
  #
  # This method is mostly obsolete.
  def cache_subdirs_from_name(basename)
    raise "DataProvider internal API change incompatibility (string vs userfile)" if basename.is_a?(Userfile)
    s=0    # sum of bytes
    e=0    # xor of bytes
    basename.each_byte { |i| s += i; e ^= i }
    [ sprintf("%2.2d",s % 100), sprintf("%2.2d",e % 100) ]
  end

  # Returns a relative directory path with three components
  # based on the +number+; the path will be in format
  #     "ab/cd/ef"
  # where +ab+, +cd+ et +ef+ components are two digits
  # long extracted directly from +number+. Examples:
  #
  #    Number      Path
  #    ----------- --------
  #    0           00/00/00
  #    5           00/00/05
  #    100         00/01/00
  #    2345        00/23/45
  #    462292      46/22/92
  #    1462292    146/22/92
  #
  # The path is returned as an array of string
  # components, as in
  #
  #    [ "146", "22","92" ]
  def cache_subdirs_from_id(number)
    self.class.numerical_subdir_tree_components(number) # from NumericalSubdirTree module
  end

  # Make, if needed, the three subdirectory levels for a cached file:
  #     mkdir "/CbrainCacheDir/34"
  #     mkdir "/CbrainCacheDir/34/45"
  #     mkdir "/CbrainCacheDir/34/45/77"
  def mkdir_cache_subdirs(userfile) #:nodoc:
    raise "DataProvider internal API change incompatibility (string vs userfile)" if userfile.is_a?(String)
    uid = userfile.id
    cache_root = self.cache_rootdir() # instance method, cached
    self.class.mkdir_numerical_subdir_tree_components(cache_root, uid) # from NumericalSubdirTree module
  end

  # Returns the relative path of the three subdirectory levels
  # where a file is cached:
  #     "34/45/77"
  def cache_subdirs_path(userfile) #:nodoc:
    raise "DataProvider internal API change incompatibility (string vs userfile)" if userfile.is_a?(String)
    uid  = userfile.id
    dirs = cache_subdirs_from_id(uid)
    Pathname.new(dirs[0]) + dirs[1] + dirs[2]
  end

  # Returns the full path of the two subdirectory levels:
  #     "/CbrainCacheDir/34/45/77"
  def cache_full_dirname(userfile) #:nodoc:
    raise "DataProvider internal API change incompatibility (string vs userfile)" if userfile.is_a?(String)
    self.cache_rootdir + cache_subdirs_path(userfile)
  end

  # Returns the full path of the cached file:
  #     "/CbrainCacheDir/34/45/77/basename"
  def cache_full_pathname(userfile) #:nodoc:
    raise "DataProvider internal API change incompatibility (string vs userfile)" if userfile.is_a?(String)
    basename = userfile.name
    cache_full_dirname(userfile) + basename
  end



  #################################################################
  # Internal Utility Methods
  #################################################################

  # Returns a string with a set of --exclude=ABC options for
  # a rsync command, based on the patterns configured
  # for the current Data Provider.
  def rsync_excludes #:nodoc:
    excludes = ""
    patterns = self.class.rsync_ignore_patterns
    patterns.each do |pattern|
      excludes += " " unless excludes.blank?
      excludes += "--exclude=#{shell_escape(pattern)}"
    end
    return "" if excludes.blank?
    excludes + " --delete-excluded"
  end

  # Utility method that returns true if pathname matches
  # one of the excluded patterns configured for the
  # current Data Provider.
  def is_excluded?(pathname) #:nodoc:
    patterns = self.class.rsync_ignore_patterns
    return false if patterns.empty?
    as_string = pathname.to_s
    patterns.each do |pattern|
      return true if File.fnmatch(pattern,as_string)
    end
    false
  end

  # This utility method escapes properly any string such that
  # it becomes a literal in a bash command; the string returned
  # will include the surrounding single quotes.
  #
  #   shell_escape("Mike O'Connor")
  #
  # returns
  #
  #   'Mike O'\''Connor'
  def shell_escape(s) #:nodoc:
    s.to_s.bash_escape(true)  # lib/cbrain_extensions/string_extensions/utilities.rb
  end

  # This method is used to escape properly any string such that
  # it becomes a literal in as REMOTE bash command; there are
  # two levels of escaping necessary. For instance, if you have
  # a file called "abcd()" on a remote server and you want
  # to cat it:
  #
  #   system("ssh remoteserver cat #{remote_shell_escape("abcd()")}
  #
  # will run locally
  #
  #   ssh remote server cat \''abcd()'\'
  #
  # which will run on the remoteserver
  #
  #   cat 'abcd()'
  #
  def remote_shell_escape(s)
    shell_escape(shell_escape(s))
  end

  # This utility method runs a bash +command+ , captures the output
  # and returns it. The user of this method is expected to have already
  # properly escaped any special characters in the arguments to the
  # command.
  def bash_this(command) #:nodoc:
    fh = IO.popen(command,"r")
    output = fh.read
    fh.close
    output
  end

  # Returns the version number of the local rsync command
  def self.local_rsync_version
    return @_local_rsync_version_ if @_local_rsync_version_
    version_text = `rsync --version 2>&1`
    @_local_rsync_version_   = Regexp.last_match[1] if version_text =~ /rsync\s+version\s+([\d\.]+)/
    @_local_rsync_version_ ||= 'not_installed'
  end

  # Returns true if the local rsync command has support
  # for escaping special characters by default
  def self.local_rsync_protects_args?
    (local_rsync_version =~ /^3\.1\.[2-9]|^3.[2-9]|^[4-9]/).present?
  end

end
