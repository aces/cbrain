
#
# CBRAIN Project
#
# Userfile model
#
# Original author: Tarek Sherif (based on the original by P. Rioux)
#
# $Id$
#

class Userfile < ActiveRecord::Base

  Revision_info="$Id$"

  acts_as_nested_set :dependent => :destroy, :before_destroy => :move_children_to_root
  belongs_to              :user
  belongs_to              :data_provider
  has_and_belongs_to_many :tags

  #A- A userfile has one group
  belongs_to              :group
     		   
  validates_uniqueness_of :name, :scope => [ :user_id, :data_provider_id ]
  validates_presence_of   :name
  
  ###
  # Pagination for the userfile index page.
  #  Had to be modified a bit so it handles filtered results properly
  ##
  def self.paginate(files, page)
    per_page = 50
    offset = (page.to_i - 1) * per_page    
    
    ##The following was an attempt to make it so children files appear on the 
    ## same page as their parents.
    ## So far it was causing way too many problems, and I'm not sure it's worth it.
    # if files.size > 50
    #    while files[offset] && files[offset].level > 0
    #       offset += 1
    #     end
    #     while files[offset + per_page] && files[offset + per_page].level > 0
    #       per_page += 1
    #     end
    # end
    
    WillPaginate::Collection.create(page, per_page) do |pager|
      pager.replace(files[offset, per_page])
      pager.total_entries = files.size
      pager
    end
  end
    
  ###
  # Filters files based on tags.
  #   The reason this is done seperately from the sql queries
  #   is that tag filtering involves complicated joins that would
  #   make generating the queries unwieldly.
  ###
  def self.apply_tag_filters(files, filters)
    current_files = files 
    
    filters.each do |filter|
      type, term = filter.split(':')
      if type == 'tag'
        current_files = current_files.select{ |f| f.tags.any?{|t| t.name == term}  }
      end
    end
    
    current_files
  end
    
  ###  
  # Utility method for converting post parameters into the filter format
  #  used by the app.
  ###
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
  
  ###
  # For the name and file filters, the filtering is done directly
  # in the sql query.
  # This method combines the appropriate filters into a single
  # sql query.
  ### 
  def self.convert_filters_to_sql_query(filters)
    query = []
    arguments = []
    
    filters.each do |filter|
      type, term = filter.split(':')
      case type
      when 'name'
        query << "(userfiles.name LIKE ?)"
        arguments << "%#{term}%"
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
  
  ###
  # Set the attribute by which to sort the file list.
  ###
  def self.set_order(new_order, current_order)
    if new_order == 'size'
      new_order = 'type, ' + new_order
    end
    
    if new_order == current_order && new_order != 'lft'
      new_order += ' DESC'
    end
      
    new_order
  end

  # This method returns true if the string +basename+ is an
  # acceptable name for a userfile. We restrict the filenames
  # to contain printable characters only, with no slashes
  # or ASCII nulls, and starts with a letter or digit.
  #
  # TODO: support accented characters? Transform them?
  def self.is_legal_filename?(basename)
    return true if basename.match(/^[a-zA-Z0-9][\w\~\!\@\#\$\%\^\&\*\(\)\-\+\=\:\;\[\]\{\}\|\<\>\,\.\?]*$/)
    
    false
  end
  
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

end
