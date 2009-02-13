
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
  has_and_belongs_to_many :tags
  
  validates_uniqueness_of :name, :scope => :user_id
  
  def self.search(type, term = nil)
    filter_name = get_filter_name(type, term)
    files = if type
              case type.to_sym
                when :tag_search
                  find(:all, :include => :tags).select{|f| f.tags.find_by_name(term)} rescue find(:all, :include => :tags)
                when :name_search
                  find(:all, :include => :tags, :conditions => ["name LIKE ?", "%#{term}%"])
                when :minc
                  find(:all, :include => :tags, :conditions => ["name LIKE ?", "%.mnc"])
                when :jiv
                  find(:all, :include => :tags, :conditions => ["name LIKE ? OR name LIKE ?", "%.raw_byte%", "%.header"])
                end
            else
              find(:all, :include =>:tags)
            end
    [files, filter_name]
  end
  
  def self.paginate(files, page)
    per_page = 50
    offset = (page.to_i - 1) * per_page    
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
    
  def self.apply_filters(files, filters)
    current_files = files 
    
    filters.each do |filter|
      type, term = filter.split(':')
      current_files = current_files.select{ |f| f.tags.any?{|t| t.name == term}  }
    end
    
    current_files
  end
    
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
    end
  end
  
  def self.convert_filters_to_sql_query(filters)
    query = []
    arguments = []
    
    filters.each do |filter|
      type, term = filter.split(':')
      case type
      when 'name'
        query << "userfiles.name LIKE ?"
        arguments << "%#{term}%"
      when 'file'
        case term
        when 'jiv'
          query << "(userfiles.name LIKE ? OR userfiles.name LIKE ? OR userfiles.name LIKE ?)"
          arguments += ["%.raw_byte", "%.raw_byte.gz", "%.header"]
        when 'minc'
          query << "(userfiles.name LIKE ?)"
          arguments << "%.mnc"
        end
      end
    end
    
    unless query.empty?
      [query.join(" AND ")] + arguments 
    else
      []
    end
  end
  
  # Full pathname to file in the vault; note that this could
  # be a pathname on a cache directory on the local machine.
  def vaultname
    directory = Pathname.new( CBRAIN::FilevaultIsLocal ? CBRAIN::Filevault_dir : CBRAIN::Vaultcache_dir) + self.user.login
    Dir.mkdir(directory) if ! File.directory?(directory)
    (directory + self.name).to_s
  end

  # Full path name of the real vault file, likely to be on a remote machine.
  # This method is expected to be called only by applications running on
  # remote hosts
  def mainvaultname
    raise "Vault directory is local for #{self.name}" if CBRAIN::FilevaultIsLocal
    directory = Pathname.new(CBRAIN::Filevault_dir) + self.user.login
    (directory + self.name).to_s
  end

  # Synchronize official file to local cached copy
  def rsync_command_filevault_to_vaultcache
    return "true # #{self.vaultname}" if CBRAIN::FilevaultIsLocal  # "true" is the shell command!
    filevault_host = CBRAIN::Filevault_host
    filevault_user = CBRAIN::Filevault_user

    filevault_name  = self.mainvaultname
    vaultcache_name = self.vaultname

    remote_name    = "#{filevault_user}@#{filevault_host}:#{filevault_name}"

    # Adjust depending on whether or not we're syncing a directory (FileCollection)
    remote_name   += "/" if self.is_a?(FileCollection)

    # TODO we get all sorts of problems if the filenames contain spaces or quotes.
    # Proper escaping would be necessary; see rsync(1)
    "rsync -a -x --delete '#{remote_name}' '#{vaultcache_name}'"
  end

  # Synchronize local cached copy to official file
  def rsync_command_vaultcache_to_filevault
    return "true # #{self.vaultname}" if CBRAIN::FilevaultIsLocal  # "true" is the shell command!
    filevault_host = CBRAIN::Filevault_host
    filevault_user = CBRAIN::Filevault_user

    filevault_name  = self.mainvaultname
    vaultcache_name = self.vaultname

    remote_name    = "#{filevault_user}@#{filevault_host}:#{filevault_name}"

    # Adjust depending on whether or not we're syncing a directory (FileCollection)
    vaultcache_name += "/" if self.is_a?(FileCollection)

    # TODO we get all sorts of problems if the filenames contain spaces or quotes.
    # Proper escaping would be necessary; see rsync(1)
    "rsync -a -x --delete '#{vaultcache_name}' '#{remote_name}'"
  end
  
  def list_files
    [self.name]
  end
  
end
