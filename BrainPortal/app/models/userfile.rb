
#
# CBRAIN Project
#
# Userfile model
#
# Original author: Tarek Sherif
#
# $Id$
#

class Userfile < ActiveRecord::Base

  Revision_info="$Id$"

  acts_as_nested_set :dependent => :destroy, :before_destroy => :move_children_to_root
  belongs_to              :user
  has_and_belongs_to_many :tags
  
  validates_uniqueness_of :name, :scope => :user_id
  
  def extract
    success = true
    self.save_content
    
    successful_files = []
    failed_files = []
    nested_files = []
    Dir.chdir(Pathname.new(CBRAIN::Filevault_dir) + self.user.login) do
      if self.name =~ /\.tar(\.gz)?$/
        all_files = `tar tf #{self.name}`.split
        all_files.each do |file_name|
          if Userfile.find_by_name(file_name)
            failed_files << file_name
          elsif file_name =~ /\//
            nested_files << file_name
          else
            `tar xvf #{self.name} #{file_name}`
            successful_files << file_name
          end
        end
      else
        all_files = `unzip -l #{self.name}`.split("\n")[3..-3].map{ |line|  line.split[3]}
        all_files.each do |file_name|
          if Userfile.find_by_name(file_name)
            failed_files << file_name
          elsif file_name =~ /\//
            nested_files << file_name
          else
            `unzip #{self.name} #{file_name}`
            successful_files << file_name
          end
        end
      end
    end
           
    successful_files.each do |file|
      u = Userfile.new
      u.name    = file
      u.user_id = self.user_id
      u.size = File.size(u.vaultname)
      if File.file? u.vaultname
        success = false unless u.save(false)
      end
    end
    
    File.delete(self.vaultname)
    [success, successful_files, failed_files, nested_files]
  end
  
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
  
  def self.paginate(files, filters, page)
    current_files = apply_filters(files, filters)

    WillPaginate::Collection.create(page, 50) do |pager|
      pager.replace(current_files[pager.offset, pager.per_page])
      pager.total_entries = current_files.size
      pager
    end
  end
    
  def self.apply_filters(files, filters)
    current_files = files
    
    filters.each do |filter|
      type, term = filter.split(':')
      case type
      when 'name'
        current_files = current_files.select{ |f| f.name =~ /#{term}/ }
      when 'tag'
        current_files = current_files.select{ |f| f.tags.find_by_name(term)  }
      when 'file'
        case term
        when 'jiv'
          current_files = current_files.select{ |f| f.name =~ /(\.raw_byte(\.gz)?|\.header)$/ }
        when 'minc'
          current_files = current_files.select{ |f| f.name =~ /\.mnc$/ }
        end
      end
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
    
  def content
    @content ||= self.read_content
    @content
  end

  def content=(newcontent)
    @content = newcontent
    self.size = @content.size
    @content
  end
  
  def vaultname
    directory = Pathname.new(CBRAIN::Filevault_dir) + self.user.login
    Dir.mkdir(directory) unless File.directory?(directory)
    (directory + self.name).to_s
  end
  
  def save_content
    return if @content.nil?
    finalname = self.vaultname
    tmpname   = finalname + ".tmp"
    out = File.open(tmpname, "w") { |io| io.write(@content) }
    File.rename(tmpname,finalname)
  end

  def delete_content
    vaultname = self.vaultname
    File.unlink(vaultname) if File.file?(vaultname)
    
    directory = File.dirname(vaultname)
    if (Pathname.new(directory) != self.user.vault_dir) && Dir.entries(directory).size <= 2
      Dir.rmdir(directory) if File.directory?(directory)
    end
    @content=nil
  end
  
  def after_save
    self.save_content
  end
  def after_update
    self.save_content
  end
  def after_create
    self.save_content
  end
  def after_destroy
    self.delete_content
  end
  
end
