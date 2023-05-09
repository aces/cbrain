
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

require 'set'

#Abstract model representing files actually registered to the system.
#
#<b>Userfile should not be instantiated directly.</b> Instead, all files
#should be registered through one of the subclasses (SingleFile, FileCollection
#or CivetOutput as of this writing).
#
#=Attributes:
#[*name*] The name of the file.
#[*size*] The size of the file.
#= Associations:
#*Belongs* *to*:
#* User
#* DataProvider
#* Group
#*Has* *and* *belongs* *to* *many*:
#* Tag
#
class Userfile < ApplicationRecord

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  cbrain_abstract_model! # objects of this class are not to be instanciated

  before_destroy          :erase_data_provider_content_and_cache, :nullify_children
  after_destroy           :remove_spurious_sync_status

  validates               :type, :subclass => true  # this will prevent files of class Userfile to be saved

  validates               :name,
                          :presence => true,
                          :uniqueness =>  { :scope => [ :user_id, :data_provider_id, :browse_path ] },
                          :filename_format => true

  # Callbacks specific to some DataProvider properties
  before_create           :flat_dir_dp_name_uniqueness # this method is also used as a validator (see below)
  validate                :flat_dir_dp_name_uniqueness # this method is also used as a before_create callback (see above)
  before_save             :browse_path_nullify
  validate                :validate_browse_path

  # Attributes
  validates_presence_of   :user_id
  validates_presence_of   :data_provider_id
  validates_presence_of   :group_id
  validate                :validate_associations

  # Associations
  belongs_to              :user
  belongs_to              :data_provider
  belongs_to              :group
  belongs_to              :parent,
                          :class_name   => "Userfile",
                          :foreign_key  => "parent_id",
                          :optional     => true

  has_and_belongs_to_many :tags
  has_many                :sync_status
  has_many                :children,
                          :class_name   => "Userfile",
                          :foreign_key  => "parent_id"

  # Resource usage is kept forever even if userfile is destroyed.
  has_many                :resource_usage
  before_save             :track_resource_usage_update
  after_destroy           :track_resource_usage_destroy

  # Quota handler
  before_create           :check_exceeded_quota!

  # For tree sorting algorithm
  attr_accessor           :level
  attr_accessor           :tree_children
  attr_accessor           :rank_order

  # Utility named scopes
  scope :name_like,     -> (n) { where("userfiles.name LIKE ?", "%#{n.strip}%") }

  scope :has_no_parent, ->     { where(parent_id: nil) }

  scope :has_no_child,     lambda { |ignored|
                             parents_ids = Userfile.where("parent_id IS NOT NULL").raw_first_column(:parent_id).uniq
                             parents_ids.blank? ? where({}) : where("userfiles.id NOT IN (?)", parents_ids)
                           }

  scope :parent_name_like, lambda { |n|
                             matching_parents_ids = Userfile.where("name like ?", "%#{n.strip}%").raw_first_column(:id).uniq
                             where(:parent_id => matching_parents_ids)
                           }

  scope :child_name_like,  lambda { |n|
                             matching_children_ids = Userfile.where("name like ?", "%#{n.strip}%").where("parent_id IS NOT NULL").raw_first_column(:id).uniq
                             matching_parents_ids  = Userfile.where(:id => matching_children_ids).raw_first_column(:parent_id).uniq
                             where(:id => matching_parents_ids)
                           }

  scope :contain_tags, -> (n) { joins(:tags).where("tag_id IN (?)", n) }

  api_attr_visible :name, :size, :user_id, :parent_id, :type, :group_id, :data_provider_id, :group_writable, :num_files, :hidden, :immutable, :archived, :description

  ##############################################
  # Miscellaneous methods
  ##############################################

  # The site with which this userfile is associated.
  def site
    @site ||= self.user.site
  end

  # Define sort orders that don't refer to actual columns in the table.
  def self.pseudo_sort_columns
    ["tree_sort"]
  end

  # File extension for this file (helps sometimes in building urls).
  def file_extension
    self.class.file_extension(self.name)
  end

  # Return the file extension (the last '.' in the name and
  # the characters following it).
  def self.file_extension(name)
    name.scan(/\.[^\.]+\z/).last
  end

  # Return the level of the calling userfile in
  # the parentage tree.
  def level
    @level ||= 0
  end

  # This method returns true if the string +basename+ is an
  # acceptable name for a userfile. We restrict the filenames
  # to contain printable characters only, with no slashes
  # or ASCII nulls, and they must start with a letter or digit.
  def self.is_legal_filename?(basename)
    return true if basename.present? && basename.match(/\A[a-zA-Z0-9][\w\~\!\@\#\%\^\(\)\-\+\=\:\[\]\{\}\,\.\?]*\z/)
    false
  end

  # Validates and cleans up a non-blank browse path
  # Returns nil if the path is invalid; returns
  # the cleaned up path otherwise.
  # This method does not consider '.' to be a valid
  # browse path; it has to be a 'x' or 'x/y/z' etc.
  def self.is_legal_browse_path?(path)
    return nil if path.blank?
    # Clean and validate each path component
    pn = Pathname.new(path).cleanpath
    return nil if pn.absolute?
    pn = pn.to_s
    return nil if pn.bytesize > 240
    components = pn.split("/")
    bad = components.detect { |x| ! self.is_legal_filename?(x) } # class method
    return nil if bad
    pn
  end

  # Returns the name of the Userfile in an array (only here to
  # maintain compatibility with the overridden method in
  # FileCollection).
  def list_files(*args)
    @file_list ||= {}

    @file_list[args.dup] ||= if self.is_locally_cached?
                               self.cache_collection_index(*args)
                             else
                               self.provider_collection_index(*args)
                             end
  end

  # Calculates and sets the size attribute unless
  # it's already set.
  def set_size
    self.set_size! if self.size.blank?
  end

  # Calculates and sets.
  # (Abstract: should be redefined in subclass).
  def set_size!
    raise "set_size! called on Userfile. Should only be called in a subclass."
  end

  # Should return a regex pattern to identify filenames that match a given
  # userfile subclass
  def self.file_name_pattern
    nil
  end

  # Human-readable version of a userfile class name. Can be overridden
  # if necessary in subclasses.
  def self.pretty_type
    @pretty_type_name ||= self.name.gsub(/(.+)([A-Z])/, '\1 \2')
  end

  # Convenience instance method that calls the class method.
  def pretty_type
    self.class.pretty_type
  end

  # Returns whether or not the userfile is compressed using the gzip format
  def compressed?
    gz_extension_pos = (name =~ /(\.gz)$/i)
    gz_extension_pos.present?  # if no .gz extension found, file not zipped
  end

  # If the userfile has a browse_path attribute set,
  # then value returned here is a concatenation of that
  # browse_path and the name: "a/b/c/name". Otherwise, this
  # method returns just the name.
  def browse_name
    (self.browse_path.blank? ? self.name : "#{self.browse_path}/#{self.name}")
  end



  ##############################################
  # Class Polymorphism Methods
  ##############################################

  # Classes this type of file can be converted to.
  # Essentially distinguishes between SingleFile subtypes and FileCollection subtypes.
  def self.valid_file_classes
    @valid_file_classes ||= Userfile.descendants
  end

  # Valid classes for conversion as strings
  # (used by SingleTableInheritance module).
  def self.valid_sti_types
    @valid_sti_types ||= valid_file_classes.map(&:to_s)
  end

  # Instance version of the class method.
  def valid_file_classes
    self.class.valid_file_classes
  end

  # Returns a suggested file type for the current userfile, based on its extension.
  def suggested_file_type
    @suggested_file_type ||= self.valid_file_classes.find{|ft| self.name =~ ft.file_name_pattern}
  end

  # Suggest a subtype of the current class based on
  # the filename +name+ .
  def self.suggested_file_type(name)
    self.valid_file_classes.find {|ft| name =~ ft.file_name_pattern }
  end


  ##############################################
  # Taging Subsystem
  ##############################################

  # Return an array of the tags associated with this file
  # by +user+. Actually returns a ActiveRecord::Relation.
  def get_tags_for_user(user)
    user = User.find(user) unless user.is_a?(User)
    self.tags.where('tags.user_id' => user.id)
  end

  # Set the tags associated with this file to those
  # in the +tags+ array (represented by Tag objects
  # or ids).
  def set_tags_for_user(user, tags)
    user = User.find(user) unless user.is_a?(User)

    tags ||= []
    tags = [tags] unless tags.is_a? Array

    non_user_tags = self.tags
                        .where(["tags.user_id <> ? AND tags.group_id NOT IN (?)", user.id, user.group_ids])
                        .raw_first_column(:id)
    new_tag_set = tags + non_user_tags

    self.tag_ids = new_tag_set
  end



  ##############################################
  # Access restriction methods
  #
  # Note: many of these methods corresponds to
  # the names of methods in the module ResourceAccess,
  # but their local implementation is customized
  # due to peculiarities in the Userfile model.
  ##############################################

  # Returns whether or not +user+ has access to this
  # userfile.
  def can_be_accessed_by?(user, requested_access = :write)

    return true if user.has_role? :admin_user
    return true if user.id == self.user_id
    return true if user.has_role?(:site_manager) &&
                   self.user.site_id == user.site_id &&
                   self.group.site_id == user.site_id
    return true if user.is_member_of_group(self.group_id) &&
                   (self.group_writable || requested_access == :read)

    return true if self.group.public && requested_access == :read

    return false
  end

  # Returns whether or not +user+ has owner access to this
  # userfile.
  def has_owner_access?(user)
    return true if user.has_role? :admin_user
    return true if user.has_role?(:site_manager) && self.user.site_id == user.site_id && self.group.site_id == user.site_id
    return user.id == self.user_id
  end

  # Returns a scope representing the set of files accessible to the
  # given user.
  def self.accessible_for_user(user, options)
    options = options.dup
    access_options = {}
    access_options[:access_requested] = options.delete :access_requested

    scope = self.where(options)
    scope = Userfile.restrict_access_on_query(user, scope, access_options)

    scope
  end

  # Find userfile identified by +id+ accessible by +user+.
  #
  # *Accessible* files are:
  # [For *admin* users:] any file on the system.
  # [For <b>site managers </b>] any file that belongs to a user of their site,
  #                             or assigned to a group to which the user belongs.
  # [For regular users:] all files that belong to the user all
  #                      files assigned to a group to which the user belongs.
  def self.find_accessible_by_user(id, user, options = {})
    # Seems weird, it is to accommodate rails5 deprecation warning for find (accept only id)
    id = id.id if id.is_a?(Userfile)
    self.accessible_for_user(user, options).find(id)
  end

  # Find all userfiles accessible by +user+.
  #
  # *Accessible* files are:
  # [For *admin* users:] any file on the system.
  # [For <b>site managers </b>] any file that belongs to a user of their site,
  #                             or assigned to a group to which the user belongs.
  # [For regular users:] all files that belong to the user all
  #                      files assigned to a group to which the user belongs.
  def self.find_all_accessible_by_user(user, options = {})
    self.accessible_for_user(user, options)
  end

  # This method takes in an array to be used as the :+conditions+
  # parameter for Userfile.where and modifies it to restrict based
  # on file ownership or group access.
  def self.restrict_access_on_query(user, scope, options = {})
    return scope if user.has_role? :admin_user

    access_requested = options[:access_requested] || :write

    # Filter by owner
    user_ids = [ user.id ]
    if user.has_role? :site_manager
      user_ids = User.where(:site_id => user.site_id).pluck(:id)
    end

    # Filter by group
    group_ids  = user.group_ids
    group_ids |= Group.public_group_ids if access_requested != :write

    # Filter by DP
    data_provider_ids = DataProvider.find_all_accessible_by_user(user).pluck('data_providers.id')

    # The final complex relation
    scope = scope
      .where('userfiles.user_id' => user_ids) # if owner, or site manager, you CAN, period.
      .or(
        scope.model.where( # the files are in the user's groups and their DPs too
             'userfiles.group_id'         => group_ids,
             'userfiles.data_provider_id' => data_provider_ids,
        ).where( # and if we want to write, it's allowed by the file's attributes
           (access_requested != :write) ? {} : { 'userfiles.group_writable' => true }
        )
      )

    scope
  end



  ##############################################
  # Tree Traversal Methods
  ##############################################

  # Make the calling userfile a child of the argument.
  def move_to_child_of(userfile)
    if self.id == userfile.id || self.descendants.include?(userfile)
      raise ActiveRecord::ActiveRecordError, "A userfile cannot become the child of one of its own descendants."
    end

    self.parent_id = userfile.id
    self.save!

    true
  end

  # Remove parent relationship
  def remove_parent
    self.update_column(:parent_id, nil) if self.id && self.parent_id
  end

  # List all descendants of the calling userfile.
  def descendants(seen = {})
    result     = []
    seen[self.id] = true
    self.children.each do |child|
      next if seen[child.id] # defensive, against loops
      seen[child.id] = true
      result << child
      result += child.descendants(seen)
    end
    result
  end



  ##############################################
  # Synchronization Status Access Methods
  ##############################################

  # Forces the userfile to be marked
  # as 'newer' on the provider side compared
  # to whatever is in the local cache for the
  # current Rails application. Not often used.
  # Results in the destruction of the local
  # sync status object.
  def provider_is_newer
    SyncStatus.ready_to_modify_dp(self) do
      true
    end
  end

  # Forces the userfile to be marked
  # as 'newer' on the cache side of the current
  # Rails application compared to whatever is in
  # the official data provider.
  # Results in the the local sync status object
  # to be marked as 'CacheNewer'.
  def cache_is_newer
    SyncStatus.ready_to_modify_cache(self) do
      true
    end
  end

  # This method returns, if it exists, the SyncStatus
  # object that represents the synchronization state of
  # the content of this userfile on the local RAILS
  # application's DataProvider cache. Returns nil if
  # no SyncStatus object currently exists for the file.
  def local_sync_status(refresh = false)
    @syncstat = nil if refresh
    @syncstat ||= SyncStatus.where(
      :userfile_id        => self.id,
      :remote_resource_id => CBRAIN::SelfRemoteResourceId
    ).first
  end

  # Returns whether this userfile's contents has been
  # synced to the local cache. As a side effect, if
  # the data provider is marked as 'fast syncing', then
  # the sync operation will be triggered first.
  def is_locally_synced?
    syncstat = self.local_sync_status(:refresh)
    return true  if syncstat && syncstat.status == 'InSync'
    return false unless self.data_provider.is_fast_syncing?
    return false if     self.data_provider.not_syncable?
    return false unless self.data_provider.rr_allowed_syncing?
    self.sync_to_cache # will also trigger custom code in models if needed
    syncstat = self.local_sync_status(:refresh)
    return true if syncstat && syncstat.status == 'InSync'
    false
  end

  # Returns whether this userfile's contents
  # is present in the local cache and valid.
  #
  # The difference between this method and is_locally_synced?
  # is that this method will also return true if the contents
  # are more up to date on the cache than on the provider
  # (and thus are not officially "In Sync").
  def is_locally_cached?
    return true if is_locally_synced?

    syncstat = self.local_sync_status
    syncstat && syncstat.status == 'CacheNewer'
  end



  ##############################################
  # Data Provider easy access methods
  ##############################################

  # Can this file have its owner changed?
  def allow_file_owner_change?
    self.data_provider.allow_file_owner_change?
  end

  # Can two users each own a file with the same
  # name on the associated DataProvider? Returns
  # true of they cannot!
  def content_storage_shared_between_users?
    self.data_provider.content_storage_shared_between_users?
  end

  # See the description in class DataProvider
  def sync_to_cache
    self.data_provider.sync_to_cache(self)
  end

  # See the description in class DataProvider
  def sync_to_provider
    self.data_provider.sync_to_provider(self)
    self.set_size!
  end

  # See the description in class DataProvider
  def cache_prepare
    self.save! if self.id.blank? # we need an ID to prepare the cache
    self.data_provider.cache_prepare(self)
  end

  # See the description in class DataProvider
  def cache_full_path
    self.data_provider.cache_full_path(self)
  end

  # See the description in class DataProvider
  def cache_readhandle(*args, &block)
    self.data_provider.cache_readhandle(self, *args,  &block)
  end

  # See the description in class DataProvider
  def cache_writehandle(*args, &block)
    self.save!
    self.data_provider.cache_writehandle(self, *args, &block)
    self.set_size!
  end

  # See the description in class DataProvider
  def cache_copy_from_local_file(filename)
    self.save!
    self.data_provider.cache_copy_from_local_file(self, filename)
    self.set_size!
  end

  # See the description in class DataProvider
  def cache_copy_to_local_file(filename)
    self.save!
    self.data_provider.cache_copy_to_local_file(self, filename)
  end

  # See the description in class DataProvider
  def cache_erase
    self.data_provider.cache_erase(self)
  end

  # Returns an Array of FileInfo objects containing
  # information about the files associated with this Userfile
  # entry.
  #
  # Information is requested from the cache (not the actual data provider).
  def cache_collection_index(directory = :all, allowed_types = :regular)
    self.data_provider.cache_collection_index(self, directory, allowed_types)
  end

  # See the description in class DataProvider
  def provider_erase
    return true if ! self.data_provider_id
    self.data_provider.provider_erase(self)
  end

  # See the description in class DataProvider
  def provider_rename(newname)
    self.data_provider.provider_rename(self, newname)
  end

  # See the description in class DataProvider
  def provider_move_to_otherprovider(otherprovider, options = {})
    self.data_provider.provider_move_to_otherprovider(self, otherprovider, options)
  end

  # See the description in class DataProvider
  def provider_copy_to_otherprovider(otherprovider, options = {})
    self.data_provider.provider_copy_to_otherprovider(self, otherprovider, options)
  end

  # See the description in class DataProvider
  def provider_collection_index(directory = :all, allowed_types = :regular)
    self.data_provider.provider_collection_index(self, directory, allowed_types)
  end

  # See the description in class DataProvider
  def provider_readhandle(*args, &block)
    self.data_provider.provider_readhandle(self, *args,  &block)
  end

  # See the description in class DataProvider
  def provider_full_path
    self.data_provider.provider_full_path(self)
  end

  # Returns true if the data provider for the content of
  # this file is online.
  def available?
    self.data_provider.online?
  end



  ##############################################
  # Scratch Userfiles Support Methods
  ##############################################

  # This helper method provides a convenient way for a programmer
  # to request caching of a the content of some data as a temporary
  # local userfile, and get to the cache quickly if it's already there.
  #
  # The +attributes+ describes a userfile's attribute for tracking
  # the data. Normally only the 'name' is required and it should be specific
  # enough to represent a particular piece of data (e.g. a container
  # image name with full version in it). A block must be given to the
  # method, and it will be invoked if the data is not already cached.
  # The block will receive a single argument, the path to the caching subsystem
  # where the userfile's data should be installed (the path is the same
  # as that returned by 'DataProvider#cache_full_path()'. The block is
  # expected to fill this path with appropriate files and/or directories.
  #
  # The method returns the userfile object (which will have a default
  # owner of 'admin' and group of 'admin', to hide it from normal users).
  #
  # If a force refresh of the content is required, the attribute hash
  # may contain a key :force_content_update to trigger it.
  #
  # See also the documentation for the class ScratchDataProvider
  def self.find_or_create_as_scratch(attributes = {}, &block)
    cb_error "Need a block" if ! block_given?
    atts = attributes.reverse_merge(
      :user_id  => User.admin.id,
      :group_id => User.admin.own_group.id,
    ).merge(
      :data_provider_id => ScratchDataProvider.main.id
    )
    refresh = atts.delete(:force_content_update)
    file    = self.find_or_create_by(atts)
    file.save!

    # If the data is already there, just use it.
    if !refresh && file.local_sync_status.try(:status) == 'InSync'
      file.local_sync_status.touch :accessed_at
      return file
    end

    # Update or create the actual content by invoking the block
    file.cache_prepare
    SyncStatus.ready_to_modify_cache(file, 'InSync') do
      yield file.cache_full_path # allow programmer to provide content for the file
    end
    file.set_size

    # A bit of info tracking
    myself       = RemoteResource.current_resource
    backtrace    = (Rails.backtrace_cleaner.clean caller).first || "Unknown"
    file.addlog("Scratch file content created or updated on #{myself.name} (#{file.size || '?'} bytes) from #{backtrace}")

    file
  end



  ##############################################
  # Viewer Methods
  ##############################################

  public

  class Viewer #:nodoc:

    attr_reader   :userfile_class, :name, :partial
    attr_accessor :errors

    def initialize(userfile_class, viewer) #:nodoc:
      atts = viewer
      unless atts.is_a? Hash
        atts = { :userfile_class => userfile_class, :name  => viewer.to_s.classify.gsub(/(.+)([A-Z])/, '\1 \2'), :partial => viewer.to_s.underscore }
      end
      initialize_from_hash(atts.merge(:userfile_class => userfile_class))
    end

    def initialize_from_hash(atts = {}) #:nodoc:
      userfile_class = atts.delete(:userfile_class) # e.g. TextFile (the class)
      unless userfile_class.present? && userfile_class.is_a?(Class) && userfile_class < Userfile
        cb_error("Viewer =#{userfile_class}= must be associated with a Userfile class.")
      end

      unless atts.has_key?(:name) || atts.has_key?(:partial)
        cb_error("Viewer must have either name or partial defined.")
      end

      name           = atts.delete(:name)
      partial        = atts.delete(:partial)
      att_if         = atts.delete(:if)      || []
      cb_error "Unknown viewer option: '#{atts.keys.first}'." unless atts.empty?

      @userfile_class = userfile_class
      @name           = name      || partial.to_s.classify.gsub(/([a-z])([A-Z])/, '\1 \2')
      @partial        = partial   || name.to_s.gsub(/\s+/, "").underscore

      @conditions     = []
      att_if = [ att_if ] unless att_if.is_a?(Array)
      att_if.each do |method|
        cb_error "Invalid :if condition '#{method}' in model." unless method.respond_to?(:to_proc)
        @conditions << method.to_proc
      end
      @errors = []
    end

    def valid_for?(userfile) #:nodoc:
      self.apply_conditions(userfile)
      self.errors.empty?
    rescue
      false
    end

    def apply_conditions(userfile) #:nodoc:
      current_errors = []
      @conditions.each do |condition|
        result = condition.call(userfile)
        if result.is_a?(Array) # new convention
          next if result.empty? # no error messages
          current_errors += result # we have some error messages now
          next
        end
        # Old convention: any falsy or truthy values
        next if result
        current_errors << 'Viewer invalid for this file (no reason given)'
      end
      self.errors = current_errors.uniq
    end

    def ==(other) #:nodoc:
      return false unless other.is_a? Viewer
      self.name == other.name
    end

    def partial_path(alternate_partial=nil) #:nodoc:
      @userfile_class.view_path(alternate_partial.to_s.presence || @partial)
    end
  end

  # List of viewers for this model
  # Unlike the class method, this methods returns
  # just the subset of viewers that are valid for
  # this particular userfile, if conditions apply.
  #
  # This method should really be named valid_viewers()
  def viewers
    class_viewers = self.class.class_viewers.map(&:dup)
    @viewers      = class_viewers.select { |v| v.valid_for?(self) }
  end

  # List of viewers for this model
  # Return all available viewer for this userfile class
  # even if they are not valid for this specific userfile
  def viewers_with_applied_conditions #:nodoc:
    self.class.class_viewers.map(&:dup).each { |v| v.apply_conditions(self) }
  end

  # Find a VALID viewer by name or partial for this model
  def find_viewer(name)
    self.viewers.find { |v| v.name == name || v.partial.to_s == name.to_s }
  end

  # Find a viewer by name or partial for this model (even if invalid)
  def find_viewer_with_applied_conditions(name)
    self.viewers_with_applied_conditions.find { |v| v.name == name || v.partial.to_s == name.to_s }
  end

  # See the class method of the same name.
  def view_path(partial_name=nil)
     self.class.view_path(partial_name)
  end

  # See the class method of the same name.
  def public_path(public_file=nil)
     self.class.public_path(public_file)
  end

  private # Viewer methods

  # Returns the directory where the custom view code of the current model
  # can be found, typically under the CBRAIN plugins directory. For a
  # model such as TextFile, it would map to a single directory:
  #
  #   "/path/to/cbrain_plugins/installed-plugins/userfiles/text_file/views"
  #
  # If given a basename or relative path for a partial (without the leading
  # underscore), will return the path to that partial. E.g. with "abc/def"
  #
  #   "/path/to/cbrain_plugins/installed-plugins/userfiles/text_file/views/abc/_def"
  #
  # Returns a Pathname object.
  def self.view_path(partial_name=nil)
    base = Pathname.new(CBRAIN::UserfilesPlugins_Dir) + self.to_s.underscore + "views"
    return base if partial_name.to_s.blank?
    partial_name = Pathname.new(partial_name.to_s).cleanpath
    raise "View partial path outside of userfile plugin." if partial_name.absolute? || partial_name.to_s =~ /\A\.\./
    base = base + partial_name.to_s.sub(/([^\/]+)\z/,'_\1')
    base
  end

  # Returns the directory where some public assets (files) for the current model
  # can be found, as served from the webserver. For a model such as TextFile,
  # it would map to this relative path:
  #
  #   "/cbrain_plugins/userfiles/text_file"
  #
  # This relative path, as seen from the "public" directory of the Rails app,
  # is a symbolic link to the "views/public" subdirectory where the userfile plugin
  # was installed.
  #
  # When given an argument 'public_file', the path returned will be extended
  # to point to a sub file of that directory. E.g. with "abc/def.csv" :
  #
  #   "/cbrain_plugins/userfiles/text_file/abc/def.csv"
  #
  # Returns nil if no file exists that match the argument 'public_file'.
  # Otherwise, returns a Pathname object.
  def self.public_path(public_file=nil)
    base = Pathname.new("/cbrain_plugins/userfiles") + self.to_s.underscore
    return base if public_file.to_s.blank?
    public_file = Pathname.new(public_file.to_s).cleanpath
    raise "Public file path outside of userfile plugin." if public_file.absolute? || public_file.to_s =~ /\A\.\./
    base = base + public_file
    return nil unless File.exists?((Rails.root + "public").to_s + base.to_s)
    base
  end

  # Add a viewer to the calling class.
  # Arguments can be one or several hashes,
  # strings or symbols used as arguments to
  # create Viewer objects.
  def self.has_viewer(*new_viewers)
    viewers = new_viewers.map { |hash_or_name| hash_or_name.is_a?(Viewer) ? hash_or_name : Viewer.new(self,hash_or_name) }
    viewers.each              { |v|            add_viewer(v) }
    viewers
  end

  # Synonym for .has_viewer.
  def self.has_viewers(*new_viewers)
    self.has_viewer(*new_viewers)
  end

  # Remove all previously defined viewers
  # for the calling class.
  def self.reset_viewers
    @ancestor_viewers = []
    @local_viewers    = []
  end

  # Add a viewer to the calling class. Unlike .has_viewer
  # the argument is a single Viewer object.
  def self.add_viewer(viewer)
    if self.class_viewers.include?(viewer)
      cb_error "Redefinition of viewer in class #{self.name}."
    end
    @local_viewers << viewer
  end

  # List viewers for the calling class.
  # Returns an array containing, first, the viewers
  # registered in this class, followed by the viewers
  # registered in superclasses (if any).
  def self.class_viewers
    unless @ancestor_viewers
      if self.superclass.respond_to? :class_viewers
        @ancestor_viewers = self.superclass.class_viewers
      end
    end
    @ancestor_viewers ||= []
    @local_viewers    ||= []
    @local_viewers + @ancestor_viewers
  end

  # Find viewer by name or partial; unlike the instance
  # method of the same name, no filtering is performed:
  # all viewers are examined to find a match and the first
  # one is returned.
  def self.find_viewer(name)
    class_viewers.find { |v| v.name == name || v.partial.to_s == name.to_s }
  end

  ##############################################
  # Content Methods
  ##############################################

  public

  # Class representing the way in which the content
  # of a userfile can be transferred to a client.
  # Created by using the #has_content directive
  # in a Userfile subclass.
  # ContentLoaders are defined by two parameters:
  # [method] an instance method defined for the
  #          class that will prepare the data for
  #          transfer.
  # [type]   the type of data being transferred.
  #          Generally, this is the the key to be
  #          used in the hash given to a render
  #          call in the controller. One special
  #          is :send_file, which the controller
  #          will take as indicating that the
  #          ContentLoader method will return
  #          the path of a file to be sent directly.
  # For example, if one wished to send the content
  # as xml, one would first define the content loader
  # method:
  #  def generate_xml
  #     ... # make the xml
  #  end
  # And then register the loader using #has_content:
  #  has_content :method => generate_xml, :type => :xml
  # The #has_content directive can also take a single
  # symbol or string, which it will assume is the
  # name of the content loader method, and setting
  # the type to :send_file.
  class ContentLoader
    attr_reader :method, :type

    def initialize(content_loader) #:nodoc:
      atts = content_loader
      unless atts.is_a? Hash
        atts = {:method => atts}
      end
      initialize_from_hash(atts)
    end

    def initialize_from_hash(options = {}) #:nodoc:
      cb_error "Content loader must have method defined." if options[:method].blank?
      @method = options[:method].to_sym
      @type   = (options[:type]  || :send_file).to_sym
    end

    def ==(other) #:nodoc:
      return false unless other.is_a? ContentLoader
      self.method == other.method
    end
  end

  # List of content loaders for this model
  def content_loaders
    self.class.content_loaders
  end

  # Find a content loader for this model. Priority is given
  # to finding a matching method name. If none is found, then
  # an attempt is made to match on the type. There may be several
  # type matches so the first is returned.
  def find_content_loader(meth)
    self.class.find_content_loader(meth)
  end

  private # Content methods

  # Add a content loader to the calling class.
  # Returns an array containing, first, the viewers
  # registered in this class, followed by the viewers
  # registered in superclasses (if any).
  def self.has_content(options = {})
    new_content = ContentLoader.new(options)
    @class_loaders ||= []
    if @class_loaders.include?(new_content)
      cb_error "Redefinition of content loader in class #{self.name}."
    end
    @class_loaders << new_content
  end

  # List content loaders for the calling class.
  def self.content_loaders
    unless @ancestor_loaders
      if self.superclass.respond_to? :content_loaders
        @ancestor_loaders = self.superclass.content_loaders
      end
    end
    @ancestor_loaders ||= []
    @class_loaders    ||= []
    @class_loaders + @ancestor_loaders
  end

  # Find a content loader for this model. Priority is given
  # to finding a matching method name. If none is found, then
  # an attempt is made to match on the type. There may be several
  # type matches so the first is returned.
  def self.find_content_loader(meth)
    return nil if meth.blank?
    method = meth.to_sym
    self.content_loaders.find { |cl| cl.method == method } ||
    self.content_loaders.find { |cl| cl.type == method }
  end



  ##############################################
  # ActiveRecord Callbacks
  ##############################################

  private

  def validate_associations #:nodoc:
    unless DataProvider.where( :id => self.data_provider_id ).exists?
      errors.add(:data_provider, "does not exist")
    end
    unless User.where( :id => self.user_id ).exists?
      errors.add(:user, "does not exist")
    end
    unless Group.where( :id => self.group_id ).exists?
      errors.add(:group, "does not exist")
    end
  end

  # Before destroy callback
  def erase_data_provider_content_and_cache #:nodoc:
    self.cache_erase rescue true
    self.provider_erase
    true
  end

  # before_destroy callback
  def nullify_children #:nodoc:
    self.children.each(&:remove_parent)
  end

  # after_destroy callback
  def remove_spurious_sync_status #:nodoc:
    SyncStatus.where(:userfile_id => self.id).delete_all
    true
  end

  # before_save callback; often files are saved with
  # no size at first, and size is updated in a later
  # operation.
  def track_resource_usage_update #:nodoc:
    return true unless self.id && self.size
    return true unless self.changed_attributes.has_key?("size")
    prev_value = self.changed_attributes["size"]
    return true if prev_value == self.size
    delta = self.size - (prev_value || 0)
    return true if delta == 0
    SpaceResourceUsageForUserfile.create(
      :value              => delta,
      :user_id            => self.user_id,
      :group_id           => self.group_id,
      :userfile_id        => self.id,
      :data_provider_id   => self.data_provider_id,
      :remote_resource_id => RemoteResource.current_resource.id,
   )
   true
  end

  # after_destroy callback
  def track_resource_usage_destroy #:nodoc:
    return true unless self.id && self.size && self.size > 0
    SpaceResourceUsageForUserfile.create(
      :value              => -(self.size),
      :user_id            => self.user_id,
      :group_id           => self.group_id,
      :userfile_id        => self.id,
      :userfile_type      => self.type, # we need to provide this directly because self will be deleted
      :userfile_name      => self.name, # we need to provide this directly because self will be deleted
      :data_provider_id   => self.data_provider_id,
      :remote_resource_id => RemoteResource.current_resource.id,
   )
   true
  end

  # This method is used as a validator, and as a before_create callback.
  # Files on data providers where all files are in the same directory
  # cannot be registered or created such that the same filename is
  # used by two entries in the DB.
  def flat_dir_dp_name_uniqueness #:nodoc:
    return true if self.data_provider_id.blank? # no check to make
    return true if ! self.data_provider.content_storage_shared_between_users?
    check_dup = Userfile.where(
      :name             => self.name,
      :data_provider_id => self.data_provider_id,
      :browse_path      => self.browse_path,
    )
    check_dup = check_dup.where(["id <> ?", self.id]) if self.id # if current file is registered, ignore that one
    return true unless check_dup.exists?
    errors.add(:name, "already exists on data provider (and may belong to another user)")
    false
  end

  # This method is used as a before_save callback.
  # If a userfile record has a browse_path present, nullify it if
  # the associated data provider does not have the browse_path capability
  # (most DPs don't have this capability).
  # This rarely happens when a file record is reassigned/duped to a new DP.
  def browse_path_nullify #:nodoc:
    return true if self.data_provider_id.blank? # no check to make
    return true if self.browse_path.nil?        # also
    return true if self.data_provider.has_browse_path_capabilities? # we keep browse_path as-is
    self.browse_path = nil
    true
  end

  # Make sure that browse_path has a proper value; this
  # depends on which DataProvider is associated with the userfile.
  def validate_browse_path
    return true if self.data_provider_id.blank? # no check to make
    return true if self.browse_path.nil?
    if ! self.data_provider.has_browse_path_capabilities? # it's not supposed to be set
      self.errors.add(:browse_path, 'has a value when it should not')
      return false
    end
    cleaned = self.class.is_legal_browse_path?(self.browse_path)
    if ! cleaned
      self.errors.add(:browse_path, 'is invalid')
      return false
    end
    true
  end

  # This method is invoked before the creation of any file.
  # It will raise an CbrainDiskQuotaExceeded exception if the
  # user has already exceeded a quota (space, or number of files) for the DP.
  def check_exceeded_quota!
    DiskQuota.exceeded!(self.user_id, self.data_provider_id)
    true
  end



  ##################################################################
  # BOOT-TIME Support
  ##################################################################

  public

  # Patch: pre-load all model files for the subclasses
  def self.preload_subclasses
    Dir.chdir(CBRAIN::UserfilesPlugins_Dir) do
      Dir.glob("*").select { |dir| File.directory?(dir) }.each do |model_dir|
        model_file = "#{model_dir}/#{model_dir}.rb"  # e.g.  "mp3_file/mp3_file.rb" for class Mp3File
        next unless File.file?(model_file)
        model = model_dir.classify
        next if Object.const_defined? model # already loaded? Skip.
        #puts_blue "Loading Userfile subclass #{model} from #{model_file} ..."
        require_dependency "#{CBRAIN::UserfilesPlugins_Dir}/#{model_file}"
      end
    end
  end

end

