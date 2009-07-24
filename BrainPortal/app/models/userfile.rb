
#
# CBRAIN Project
#
# Userfile model
#
# Original author: Tarek Sherif (based on the original by P. Rioux)
#
# $Id$
#

require 'set'

#Abstract model representing files actually registered to the system.
#
#<b>Userfile should not be instantiated directly.</b> Instead, all files
#should be registered through one of the subclasses (SingleFile, FileCollection
#or CivetCollection as of this writing).
#
#=Attributes:
#[*name*] The name of the file.
#[*size*] The size of the file.
#[*task*] The DrmaaTask (if any) that produced this file.
#=Acts as:
#[*nested_set*] The nested set module allows for the creation of 
#               a tree structure of userfiles. Userfiles created
#               as the output of some processing on a given userfile
#               will be considered children of that userfile.
#= Associations:
#*Belongs* *to*:
#* User
#* DataProvider
#* Group
#*Has* *and* *belongs* *to* *many*:
#* Tag
class Userfile < ActiveRecord::Base

  Revision_info="$Id$"
  Default_num_pages = "50"

  acts_as_nested_set :dependent => :destroy, :before_destroy => :move_children_to_root
  belongs_to              :user
  belongs_to              :data_provider
  belongs_to              :group
  has_and_belongs_to_many :tags
     		   
  validates_uniqueness_of :name, :scope => [ :user_id, :data_provider_id ]
  validates_presence_of   :name
  validates_presence_of   :group_id
    
  #Return an array of the tags associated with this file
  #by +user+.
  def get_tags_for_user(user)
    u = user
    unless u.is_a? User
      u = User.find(u)
    end
    
    self.tags.select{|t| (self.tag_ids & u.tag_ids).include? t.id}
  end
  
  #Set the tags associated with this file to those
  #in the +tags+ array (represented by Tag objects
  #or ids).
  def set_tags_for_user(user, tags)
    all_tags = self.tag_ids
    current_user_tags = self.tag_ids & user.tag_ids
    
    self.tag_ids = (all_tags - current_user_tags) + (tags || [])
  end
    
  #Produces the list of files to display for a paginated Userfile index
  #view.
  def self.paginate(files, page, prefered_per_page)
    per_page = (prefered_per_page || Default_num_pages).to_i
    offset = (page.to_i - 1) * per_page    
    
    WillPaginate::Collection.create(page, per_page) do |pager|
      pager.replace(files[offset, per_page])
      pager.total_entries = files.size
      pager
    end
  end
  
  #Filters the +files+ array of userfiles, based on the 
  #tag filters in the +tag_filters+ array and +user+, the current user.
  def self.apply_tag_filters_for_user(files, tag_filters, user)
    current_files = files
    
    unless tag_filters.blank?
      tags = tag_filters.collect{ |tf| user.tags.find_by_name( tf )}
      current_files = current_files.select{ |f| (tags & f.get_tags_for_user(user)) == tags}
    end
    
    current_files
  end
    
  #Converts a filter request sent as a POST parameter from the
  #Userfile index page into the format used by the Session model
  #to store currently active filters.
  def self.get_filter_name(type, term)
    case type
    when 'name_search'
      'name:' + term
    when 'tag_search'
      'tag:' + term
    when 'jiv'
      'file:jiv'
    when 'minc'
      'file:minc'
    when 'cw5'
      'file:cw5'
    when 'flt'
      'file:flt'
    when 'mls'
      'file:mls'            
    end
  end
  
  #Convert the array of +filters+ into an sql query string
  #to be used in pulling userfiles from the database.
  #Note that tag filters will not be converted, as they are
  #handled by the apply_tag_filters method.
  def self.convert_filters_to_sql_query(filters)
    query = []
    arguments = []
    
    filters.each do |filter|
      type, term = filter.split(':')      
      case type
      when 'name'
        query << "(userfiles.name LIKE ?)"
        arguments << "%#{term}%"
      when 'custom'
        custom_filter = CustomFilter.find_by_name(term)
        unless custom_filter.query.blank?
          query << "(#{custom_filter.query})"
          arguments += custom_filter.variables
        end
      when 'file'
        case term
        when 'jiv'
          query << "(userfiles.name LIKE ? OR userfiles.name LIKE ? OR userfiles.name LIKE ?)"
          arguments += ["%.raw_byte", "%.raw_byte.gz", "%.header"]
        when 'minc'
          query << "(userfiles.name LIKE ?)"
          arguments << "%.mnc"
        when 'cw5'
          query << "(userfiles.name LIKE ? OR userfiles.name LIKE ? OR userfiles.name LIKE ? OR userfiles.name LIKE ?)"
          arguments += ["%.flt", "%.mls", "%.bin", "%.cw5" ]
        when 'flt'
          query << "(userfiles.name LIKE ?)"
          arguments += ["%.flt"]
        when 'mls'
          query << "(userfiles.name LIKE ?)"
          arguments += ["%.mls"]
        end
      end
    end
    
    unless query.empty?
      [query.join(" AND ")] + arguments 
    else
      []
    end

  end
  
  #Returns whether or not +user+ has access to this
  #userfile.
  def can_be_accessed_by?(user)
    if user.has_role? :admin
      return true
    end
    if user.id == self.user_id
      return true
    end
    if user.group_ids.include?(self.group_id) && self.group_writable
      return true
    end
    
    false
  end
  
  #Find userfile identified by +id+ accessible by +user+.
  #
  #*Accessible* files are:
  #[For *admin* users:] any file on the system.
  #[For regular users:] all files that belong to the user all 
  #                     files assigned to a group to which the user belongs.
  def self.find_accessible_by_user(id, user, options = {})
    new_options = options
    unless user.has_role? :admin
      conditions = options[:conditions] || []
      conditions = [conditions] if conditions.is_a? String
      new_options[:conditions] = Userfile.restrict_access_on_query(user, conditions, options)
    end
    new_options.delete :access_requested
    
    find(id, new_options)
  end
  
  #Find all userfiles accessible by +user+.
  #
  #*Accessible* files are:
  #[For *admin* users:] any file on the system.
  #[For regular users:] all files that belong to the user all 
  #                     files assigned to a group to which the user belongs.
  def self.find_all_accessible_by_user(user, options = {})
    new_options = options
    
    unless user.has_role? :admin
      conditions = options[:conditions] || []
      conditions = [conditions] if conditions.is_a? String
      new_options[:conditions] = Userfile.restrict_access_on_query(user, conditions, options)
    end
    new_options.delete :access_requested
    
    find(:all, new_options)
  end
  
  #This method takes in an array to be used as the :+conditions+
  #parameter for Userfile.find and modifies it to restrict based
  #on file ownership or group access.
  def self.restrict_access_on_query(user, query, options = {})
    access_requested = options[:access_requested] || :write
    if access_requested.to_sym == :read
      query_string = ["((userfiles.user_id = ?) OR (userfiles.group_id IN (?)))", query.shift].compact.join(" AND ")
    else
      query_string = ["((userfiles.user_id = ?) OR (userfiles.group_id IN (?) AND userfiles.group_writable = true))", query.shift].compact.join(" AND ")
    end

    variables = [user.id, user.group_ids] + query
    
    query = [query_string] + variables
    
    query
  end
  
  #Set the attribute by which to sort the file list
  #in the Userfile index view.
  def self.set_order(new_order, current_order)
    if new_order == 'size'
      new_order = 'type, ' + new_order
    end
    
    if new_order == current_order && new_order != 'lft'
      new_order += ' DESC'
    end
      
    new_order
  end

  #This method returns true if the string +basename+ is an
  #acceptable name for a userfile. We restrict the filenames
  #to contain printable characters only, with no slashes
  #or ASCII nulls, and they must start with a letter or digit.
  def self.is_legal_filename?(basename)
    return true if basename.match(/^[a-zA-Z0-9][\w\~\!\@\#\$\%\^\&\*\(\)\-\+\=\:\;\[\]\{\}\|\<\>\,\.\?]*$/)
    
    false
  end
  
  #Returns the name of the Userfile in an array (only here to 
  #maintain compatibility with the overridden method in
  #FileCollection).
  def list_files
    [self.name]
  end

  ##############################################
  # Data Provider easy access methods
  ##############################################

  # See the description in class DataProvider
  def sync_to_cache
    self.data_provider.sync_to_cache(self)
  end

  # See the description in class DataProvider
  def sync_to_provider
    self.data_provider.sync_to_provider(self)
  end

  # See the description in class DataProvider
  def cache_prepare
    self.data_provider.cache_prepare(self)
  end
  
  # See the description in class DataProvider
  def cache_full_path
    self.data_provider.cache_full_path(self)
  end

  # See the description in class DataProvider
  def provider_erase
    self.data_provider.provider_erase(self)
  end
  
  # See the description in class DataProvider
  def provider_rename(newname)
    self.data_provider.provider_rename(self,newname)
  end
  
  # See the description in class DataProvider
  def cache_readhandle(&block)
    self.data_provider.cache_readhandle(self,&block)
  end

  # See the description in class DataProvider
  def cache_writehandle(&block)
    self.data_provider.cache_writehandle(self,&block)
  end

  # See the description in class DataProvider
  def cache_copy_from_local_file(filename)
    self.data_provider.cache_copy_from_local_file(self,filename)
  end

  # See the description in class DataProvider
  def cache_copy_to_local_file(filename)
    self.data_provider.cache_copy_to_local_file(self,filename)
  end

  ##################################
  # Active Record Callbacks
  ##################################

  # This will work will all subclasses.
  def before_destroy #:nodoc:
    self.provider_erase
  end

end
