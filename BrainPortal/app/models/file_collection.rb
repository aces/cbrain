
#
# CBRAIN Project
#
# File collection model.
# Represents an entry in the userfile list that corresponds to multiple files.
#
# Original author: Tarek Sherif
#
# $Id$
#

require 'ftools'
require 'fileutils'
require 'find'

#This model is meant to represent an arbitrary collection files (which
#may or may not contain subdirectories) registered as a single entry in 
#the userfiles table. 
class FileCollection < Userfile 
  
  Revision_info="$Id$"
  
  # Extract a collection from an archive.
  # The user_id, provider_id and name attributes must already be
  # set at this point.
  def extract_collection_from_archive_file(archive_file_name)

    self.cache_prepare
    directory = self.cache_full_path
    Dir.mkdir(directory) unless File.directory?(directory)

    if archive_file_name !~ /^\//
      archive_file_name = Dir.pwd + "/" + archive_file_name
    end

    Dir.chdir(directory) do
      escaped_tmparchivefile = archive_file_name.gsub("'", "'\\\\''")
      if archive_file_name =~ /(\.tar.gz|\.tgz)$/i
        system("gunzip < '#{escaped_tmparchivefile}' | tar xf -")
      elsif archive_file_name =~ /\.tar$/i
        system("tar -xf '#{escaped_tmparchivefile}'")
      elsif archive_file_name =~ /\.zip/i
        system("unzip '#{escaped_tmparchivefile}'") 
      else
        raise "Cannot extract files from archive with unknown extension '#{archive_file_name}'"
      end
    end

    self.remove_unwanted_files
    
    
    #Get size
    #total_size = IO.popen("du -s #{directory}","r") { |fh| fh.readline.split[0].to_i}

    self.flatten
    Dir.chdir(self.cache_full_path.parent) do
      self.size = self.list_files.inject(0){ |total, file_name|  total += File.size(file_name) }
    end
    self.num_files = self.list_files.size 
    self.sync_to_provider
    self.save

    true
  end
  
  def format_size
    super + " (#{self.num_files} files)"
  end
  
  #Checks whether the size attributes (size and num_files) have been set.
  def size_set?
    ! (self.size.blank? || self.num_files.blank?)
  end
  
  #Calculates and sets the size attribute.
  def set_size
    self.set_size! unless self.size_set?
  end

  #Calculates and sets the size attribute (active recount forced)
  def set_size!
    local_sync = self.local_sync_status
    unless local_sync && local_sync.status == "InSync"
      return false
    end
    
    Dir.chdir(self.cache_full_path.parent) do
      #self.size = IO.popen("du -s #{self.name}","r") { |fh| fh.readline.split[0].to_i}
      self.size = self.list_files.inject(0){ |total, file_name|  total += File.size(file_name) }
      self.num_files = self.list_files.size
      self.save!
    end
    
    true
  end
  
  
  #Merge the collections and files in the array +userfiles+
  #Returns the status of the merge as a *symbol*:
  #[*success*] if the merge is successful.
  #[*collision*] if the collections share common file names (the merge is aborted in this case).
  #[*failure*] if the merge failed for some other reason.
  def merge_collections(userfiles)    
    full_names = userfiles.inject([]){|list, file| list += file.list_files}    
    raw_names = full_names.map{ |file| file.sub(/^.+\//, "") }
    
    unless raw_names.uniq.size == raw_names.size
      return :collision
    end
    
    suffix = Time.now.to_i
    
    while self.user.userfiles.any?{ |f| f.name == "Collection-#{suffix}"}
      suffix += 1
    end
    
    self.name = "Collection-#{suffix}"
    self.cache_prepare
    destname = self.cache_full_path.to_s
    Dir.mkdir(destname) unless File.directory?(destname)
    
    userfiles.each do |file|

      file.sync_to_cache
      filename = file.cache_full_path.to_s
      
      FileUtils.cp_r(filename,destname) # file or dir INTO dir

    end
    
    Dir.chdir(self.cache_full_path.parent) do
      self.size = self.list_files.inject(0){ |total, file_name|  total += File.size(file_name) }
    end
    self.num_files = self.list_files.size
    
    if self.save!
      self.sync_to_provider
      :success
    else
      :failure
    end
  end
  
  #Returns an array of the relative paths to all files contained in this collection.
  def list_files    
    return @file_list if @file_list
    Dir.chdir(self.cache_full_path.parent) do
      escaped_name = self.name.gsub("'", "'\\\\''")
      IO.popen("find '#{escaped_name}' -type f -print") do |fh|
        @file_list = fh.readlines.map(&:chomp)
      end
      @file_list.sort! { |a,b| a <=> b }
    end
  end
  
  #Returns an array of the relative paths to all subdirectories contained in this collection.
  def list_dirs
    return @dir_list if @dir_list
    Dir.chdir(self.cache_full_path.parent) do
      escaped_name = self.name.gsub("'", "'\\\\''")
      IO.popen("find '#{escaped_name}' -type d -print") do |fh|
        @dir_list = fh.readlines.map(&:chomp)
      end
      @dir_list.sort! { |a,b| a <=> b }
    end
  end
  
  #mathieu desrosiers
  #Returns an array of the relative paths to first level subdirectories contained in this collection.
  #this function only for usage in spmbatch, feel free to contact me if you would like to remove it.
  def list_first_level_dirs
    return @dir_list if @dir_list
    Dir.chdir(self.cache_full_path.parent) do
      escaped_name = self.name.gsub("'", "'\\\\''")
      IO.popen("find '#{escaped_name}' -type d -mindepth 1 -maxdepth 1 -print") do |fh|
        @dir_list = fh.readlines.map(&:chomp)
      end
      @dir_list.sort! { |a,b| a <=> b }
    end
  end  
  
  #Format size for display (make it more human-readable).
  # def format_size
  #   "#{self.size || "?"} files" 
  # end
  
  # Returns a simple keyword identifying the type of
  # the userfile; used mostly by the index view.
  def pretty_type
    "(Collection)"
  end

  #Mathieu Desrosiers
  #remove unwanted .DS_Store file and "._" files from a packages if there is some
  #this function may be harmfull and only matter if the archive came from a MACOSX archive
  def remove_unwanted_files
    dir_name = self.cache_full_path
    Dir.chdir(dir_name) do       
      Find.find("."){|file|
        if File.fnmatch("._*",File.basename(file))
          File.delete(file)
        elsif File.fnmatch(".DS_Store",File.basename(file))
          File.delete(file)
        end
      }
    end
  end

  #Remove the common root (if there is one) from the directory structure of this collection.
  def flatten
    dir_name = self.cache_full_path

    Dir.chdir(dir_name) do      
      files = []
      IO.popen("find . -type f -print") do |fh|
        files = fh.readlines.map(&:chomp)
      end
      base = ""
      source = files[0].split('/')
      source.each do |dir|
        break unless files.all? {|d| d =~ /^#{base + dir + '/'}/}
        base += dir + '/'
      end
      
      Dir.entries(base).each do |entry|
        unless entry == "." || entry == ".."
          File.move(base + entry, "./")
        end
      end

      base_dirs = base.split('/')
      base_dirs.shift               #remove the .
      while !base_dirs.empty?
        Dir.rmdir(base_dirs.join('/'))
        base_dirs.pop
      end
    end

  end
end


