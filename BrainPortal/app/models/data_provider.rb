
#
# CBRAIN Project
#
# $Id$
#

require 'fileutils'
require 'pathname'

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
# The cache_readhandle() and cache_writehandle() methods *cannot* be used
# to access FileCollections, as these are modeled on the filesystem by
# subdirectories. However, the methods cache_copy_to_local_file() and
# cache_copy_from_local_file() will work perfectly well, assuming that
# the +localfile+ they are given in argument is itself a local subdirectory.
#
# When creating new FileCollections, the cache_prepare() method should be
# called once first, then the cache_full_path() can be used to obtain
# a full path to the subdirectory where the collection will be created
# (note that the subdirectory itself will not be created for you).
#
# = Here is the complete list of API methods:
#
# == Status methods:
#
# * is_alive?
# * is_alive!
# * is_browsable?
#
# == Access restriction methods:
#
# * can_be_accessed_by(user)    # user is a User object
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
# * cache_readhandle(userfile)
# * cache_writehandle(userfile)
# * cache_copy_from_local_file(userfile,localfilename)
# * cache_copy_to_local_file(userfile,localfilename)
# * cache_erase(userfile)
#
# Note that all of these are also present in the Userfile model.
#
# == Provider-side methods:
#
# * provider_erase(userfile)
# * provider_rename(userfile,newname)
# * provider_move_to_otherprovider(userfile,otherprovider)
# * provider_list_all
#
# Note that provider_erase() and provider_rename() are also present in
# the Userfile model.
#
# = Aditional notes
#
# Most methods raise an exception if the provider's +online+ attribute is
# false, or if trying to perform some write operation and the provider's
# +read_only+ attribute is true.
#
# None of the methods issue a save() operation on the +userfile+
# they are given in argument; this means that after a successful
# provider_rename() or provider_move_to_otherprovider(), the caller
# must call the save() method explicitely.
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
# * impl_provider_list_all()
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
# *Has* *many*:
# * UserPreference
class DataProvider < ActiveRecord::Base

  Revision_info="$Id$"

  belongs_to  :user
  belongs_to  :group
  has_many    :user_preferences

  validates_uniqueness_of :name
  validates_presence_of   :name, :user_id, :group_id
  validates_format_of     :name, :with  => /^[a-zA-Z0-9][\w\-\=\.\+]*$/,
                                 :message  => 'only the following characters are valid: alphanumeric characters, _, -, =, +, ., ?, !',
                                 :allow_blank => true

  # This method must not block, and must respond quickly.
  # Returns +true+ or +false+.
  def is_alive?
    return false if self.online == false
    impl_is_alive?
  end

  # Raises an exception if is_alive? is +false+, otherwise
  # it returns +true+.
  def is_alive!
    raise "Error: data provider is not accessible right now." unless self.is_alive?
    true
  end

  # This method returns true if the provider is 'browsable', that is
  # you can call provider_list_all() without fear of an exception.
  # Most data providers are not browsable.
  def is_browsable?
    false
  end

  # Returns true if +user+ can access this provider.
  def can_be_accessed_by(user)
    user.group_ids.include?(group_id)
  end
  
  #Find data provider identified by +id+ accessible by +user+.
  #
  #*Accessible* data providers  are:
  #[For *admin* users:] any data provider on the system.
  #[For regular users:] all data providers that belong to a group to which the user belongs.
  #
  #*Note*: the options hash will accept any of the standard ActiveRecord +find+ parameters
  #except for :conditions which is set internally.
  def self.find_accessible_by_user(id, user, options = {})
    new_options = options
    
    unless user.has_role? :admin
      new_options[:conditions] = ["(data_providers.group_id IN (?))", user.group_ids]
    end
    
    find(id, new_options)
  end
  
  #Find all data providers accessible by +user+.
  #
  #*Accessible* data providers  are:
  #[For *admin* users:] any data provider on the system.
  #[For regular users:] all data providers that belong to a group to which the user belongs.
  #
  #*Note*: the options hash will accept any of the standard ActiveRecord +find+ parameters
  #except for :conditions which is set internally.
  def self.find_all_accessible_by_user(user, options = {})
    new_options = options
    
    unless user.has_role? :admin
      new_options[:conditions] = ["(data_providers.group_id IN (?))", user.group_ids]
    end
    
    find(:all, new_options)
  end

  # Synchronizes the content of +userfile+ as stored
  # on the provider into the local cache.
  def sync_to_cache(userfile)
    raise "Error: provider is offline." unless self.online
    impl_sync_to_cache(userfile)
  end

  # Synchronizes the content of +userfile+ from the
  # local cache back to the provider.
  def sync_to_provider(userfile)
    raise "Error: provider is offline."   unless self.online
    raise "Error: provider is read_only." if     self.read_only
    impl_sync_to_provider(userfile)
  end

  # Makes sure the local cache is properly configured
  # to receive the content for +userfile+; usually
  # this method is called before writing the content
  # for +userfile+ into the cached file or subdirectory.
  # Note that this method is already called for you
  # when invoking cache_writehandle(userfile).
  def cache_prepare(userfile)
    raise "Error: provider is offline."   unless self.online
    raise "Error: provider is read_only." if     self.read_only
    mkdir_cache_subdirs(userfile.name)
    true
  end

  # Returns the full path to the file or subdirectory
  # where the cached content of +userfile+ is located.
  # The value returned is a Pathname object, so be careful
  # to call to_s() on it when using it as necessary.
  def cache_full_path(userfile)
    raise "Error: provider is offline."   unless self.online
    cache_full_pathname(userfile.name)
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
  def cache_readhandle(userfile)
    raise "Error: provider is offline."   unless self.online
    sync_to_cache(userfile)
    File.open(cache_full_path(userfile),"r") do |fh|
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
  def cache_writehandle(userfile)
    raise "Error: provider is offline."   unless self.online
    raise "Error: provider is read_only." if self.read_only
    cache_prepare(userfile)
    localpath = cache_full_path(userfile)
    File.open(localpath,"w") do |fh|
      yield(fh)
    end
    userfile.size = File.size(localpath)
    sync_to_provider(userfile)
  end

  # This method provides a quick way to set the cache's file
  # content to an exact copy of +localfile+, a locally accessible file.
  # The syncronization method +sync_to_provider+ will automatically
  # be called after the copy is performed.
  def cache_copy_from_local_file(userfile,localpath)
    raise "Error: provider is offline."   unless self.online
    raise "Error: provider is read_only." if self.read_only
    raise "Error: file does not exist: #{localpath.to_s}" unless File.exists?(localpath)
    cache_erase(userfile)
    cache_prepare(userfile)
    dest = cache_full_path(userfile)
    FileUtils.cp_r(localpath,dest)
    userfile.size = if File.directory?(localpath)
      Dir.entries(localpath).select { |e| e != "." && e != ".." }.size
    else
      File.size(localpath)
    end
    sync_to_provider(userfile)
  end

  # This method provides a quick way to copy the cache's file
  # to an exact copy +localfile+, a locally accessible file.
  # The syncronization method +sync_to_cache+ will automatically
  # be called before the copy is performed.
  def cache_copy_to_local_file(userfile,localpath)
    raise "Error: provider is offline."   unless self.online
    raise "Error: provider is read_only." if self.read_only
    sync_to_cache(userfile)
    FileUtils.remove_entry(localpath.to_s, true)
    source = cache_full_path(userfile)
    FileUtils.cp_r(source,localpath)
    true
  end

  # Deletes the cached copy of the content of +userfile+;
  # does not affect the real file on the provider side.
  def cache_erase(userfile)
    raise "Error: provider is offline."   unless self.online
    basename = userfile.name
    FileUtils.remove_entry(cache_full_pathname(basename), true)
    begin
      Dir.rmdir(cache_full_dirname(basename))
    rescue
    end
    true
  end

  # Deletes the content of +userfile+ on the provider side.
  def provider_erase(userfile)
    raise "Error: provider is offline."   unless self.online
    raise "Error: provider is read_only." if self.read_only
    cache_erase(userfile)
    impl_provider_erase(userfile)
  end

  # Renames +userfile+ on the provider side.
  # This will also rename the name attribute IN the
  # userfile object. A check for name collision on the
  # provider is performed first. The method returns
  # true if the rename operation was successful.
  def provider_rename(userfile,newname)
    raise "Error: provider is offline."   unless self.online
    raise "Error: provider is read_only." if self.read_only
    return true if newname == userfile.name
    return false unless Userfile.is_legal_filename?(newname)
    target_exists = Userfile.find_by_name_and_data_provider_id(newname,self.id)
    return false if target_exists
    cache_erase(userfile)
    impl_provider_rename(userfile,newname.to_s)
  end


  # Move a +userfile+ from the current provider to
  # +otherprovider+
  def provider_move_to_otherprovider(userfile,otherprovider)
    raise "Error: provider #{self.name} is offline."   unless self.online
    raise "Error: provider #{self.name} is read_only." if self.read_only
    raise "Error: provider #{otherprovider.name} is offline."   unless otherprovider.online
    raise "Error: provider #{otherprovider.name} is read_only." if otherprovider.read_only
    return true if self.id == otherprovider.id
    target_exists = Userfile.find_by_name_and_data_provider_id(userfile.name,otherprovider.id)
    return false if target_exists

    # Get path to cached copy on current provider
    sync_to_cache(userfile)
    currentcache = userfile.cache_full_path

    # Copy to other provider
    userfile.provider_id = otherprovider.id
    otherprovider.cache_copy_from_local_file(currentcache)

    # Erase on current provider
    userfile.provider_id = self.id  # temporarily set it back
    cache_erase(userfile)
    impl_provider_erase(userfile)
    userfile.provider_id = otherprovider.id  # must return it to true value

    true
  end


  # This method provides a way for a client of the provider
  # to get a list of files on the provider's side, files
  # that are not necessarily yet registered as +userfiles+.
  #
  # When called, the method accesses the provider's side
  # and returns an array of tuplets; each tuplet is
  #
  #   [ basename, size, type, mtime ]
  #
  # where
  #
  # basename:: is a file basename
  # size::     is in bytes
  # type::     is "regular" or "directory"
  # mtime::    is int seconds since unix epoch
  #
  # Note that not all data providers are meant to be browsable.
  def provider_list_all
    raise "Error: provider is offline."   unless self.online
    impl_provider_list_all
  end


  #################################################################
  # Utility Non-API
  #################################################################


  # This method is a TRANSITION utility method; it returns
  # any provider that's read/write for the user. The method
  # is used by interface pages not yet modified to ask the
  # user where files nead to be stored. The hope is that
  # it will return the main Vault provider by default.
  def self.find_first_online_rw(user)
    providers = self.find(:all, :conditions => { :online => true, :read_only => false })
    providers = providers.select { |p| p.can_be_accessed_by(user) }
    raise "No online rw provider found for user '#{user.login}" if providers.size == 0
    providers.sort! { |a,b| a.id <=> b.id }
    providers[0]
  end

  # This method creates the provider's top-level cache subdirectory.
  # It is not part of the 'user'-level API for Data Providers;
  # it's basically used by management layers and initialization code.
  # It only needs to be called once in the entire lifetime of the
  # provider, usually in before_save.
  def mkdir_cache_providerdir
    providerdir = cache_providerdir
    Dir.mkdir(providerdir) unless File.directory?(providerdir)
  end


  #################################################################
  # ActiveRecord callbacks
  #################################################################

  # This creates the PROVIDER's cache directory
  def before_save #:nodoc:
    mkdir_cache_providerdir
  end

  # This destroys the PROVIDER's cache directory
  def after_destroy #:nodoc:
    FileUtils.remove_dir(cache_providerdir, true)  # recursive
  end


  #################################################################
  protected
  #################################################################

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

  def impl_provider_list_all #:nodoc:
    raise "Error: method not yet implemented in subclass."
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
  def shell_escape(s)
    "'" + s.to_s.gsub(/'/,"'\\\\''") + "'"
  end

  # This utility method runs a bash command, intercepts the output
  # and returns it.
  def bash_this(command)
    #puts "BASH: #{command}"
    fh = IO.popen(command,"r")
    output = fh.read
    fh.close
    output
  end

  # Root directory for ALL DataProviders caches:
  #    "/CbrainCacheDir"
  # This is a class method.
  def self.cache_rootdir #:nodoc:
    Pathname.new(CBRAIN::DataProviderCache_dir)
  end

  # Root directory for DataProvider's cache dir:
  #    "/CbrainCacheDir/ProviderName"
  def cache_providerdir #:nodoc:
    Pathname.new(CBRAIN::DataProviderCache_dir) + self.name
  end

  # Returns an array of two subdirectory levels where a file
  # is cached. These are two strings of two digits each. For
  # instance, for +hello+, the method returns [ "32", "98" ].
  # Although this method is mostly used internally by the
  # caching system, it can also be used by other data providers
  # which want to build similar directory trees.
  def cache_subdirs(basename)
    s=0    # sum of bytes
    e=0    # xor of bytes
    basename.each_byte { |i| s += i; e ^= i }
    [ sprintf("%2.2d",s % 100), sprintf("%2.2d",e % 100) ]
  end

  # Make, if needed, the two subdirectory levels for a cached file:
  # mkdir "/CbrainCacheDir/ProviderName/34"
  # mkdir "/CbrainCacheDir/ProviderName/34/45"
  def mkdir_cache_subdirs(basename) #:nodoc:
    twolevels = cache_subdirs(basename)
    level1 = Pathname.new(cache_providerdir) + twolevels[0]
    level2 = level1                          + twolevels[1]
    Dir.mkdir(level1) unless File.directory?(level1)
    Dir.mkdir(level2) unless File.directory?(level2)
    true
  end

  # Returns the relative path of the two subdirectory levels:
  # "34/45"
  def cache_subdir_path(basename) #:nodoc:
    dirs = cache_subdirs(basename)
    Pathname.new(dirs[0]) + dirs[1]
  end

  # Returns the full path of the two subdirectory levels:
  # "/CbrainCacheDir/ProviderName/34/45"
  def cache_full_dirname(basename) #:nodoc:
    cache_providerdir + cache_subdir_path(basename)
  end

  # Returns the full path of the cached file:
  # "/CbrainCacheDir/ProviderName/34/45/basename"
  def cache_full_pathname(basename) #:nodoc:
    cache_full_dirname(basename) + basename
  end

end

