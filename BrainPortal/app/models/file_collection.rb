
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

class FileCollection < Userfile 
  
  Revision_info="$Id$"
  
  # Extract a collection from an archive
  # The user_id, provider_id and name attributes must already be
  # set at this point.
  def extract_collection_from_archive_file(archive_file_name)

    self.cache_prepare
    directory = self.cache_full_path
    Dir.mkdir(directory) unless File.directory?(directory)
    Dir.chdir(directory) do
      escaped_tmparchivefile = archive_file_name.gsub("'", "'\\\\''")
      if archive_file_name =~ /(\.tar.gz|\.tgz)$/i
        system("tar -xzf '#{escaped_tmparchivefile}'")
      elsif archive_file_name =~ /\.tar$/i
        system("tar -xf '#{escaped_tmparchivefile}'")
      elsif archive_file_name =~ /\.zip/i
        system("unzip '#{escaped_tmparchivefile}'") 
      else
        raise "Cannot extract files from archive with unknown extension '#{archive_file_name}'"
      end
    end

    self.flatten
    self.size = self.list_files.size
    self.sync_to_provider
    self.save

    true
  end
  
  def merge_collections(file_ids)
    userfiles = Userfile.find(file_ids)
    
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
      
      if file.is_a? FileCollection
        system("cp -f -R '#{filename.gsub("'", "'\\\\''")}/' '#{destname.gsub("'", "'\\\\''")}'")
      else
        system("cp -f '#{filename.gsub("'", "'\\\\''")}' '#{destname.gsub("'", "'\\\\''")}'")
      end
    end
    
    self.size = self.list_files.size
    
    if self.save
      self.sync_to_provider
      :success
    else
      :failure
    end
  end

  #find longest common root of a list of file paths.
  def get_common_base(files)
    return nil if files.empty?
    base = ""
    source = dirs[0].split('/')
    source.each_with_index do |dir, i|
      break unless dirs.all? {|d| d =~ /^#{base + dir + '/'}/}
      base += dir + '/'
    end
    base
  end
  
  def list_files    
    Dir.chdir(self.cache_full_path.parent) do
      @file_list ||= IO.popen("find '#{self.name.gsub("'", "'\\\\''")}' -type f").readlines.map(&:chomp)
    end
  end
  
  def list_dirs
    Dir.chdir(self.cache_full_path.parent) do
      @dir_list ||= IO.popen("find '#{self.name.gsub("'", "'\\\\''")}' -type d").readlines.map(&:chomp).reverse
    end
  end
  
  #format size for display
  def format_size
    "#{self.size || "?"} files" 
  end
  
  # Remove common root from a directory structure.
  def flatten
    dir_name = self.cache_full_path

    Dir.chdir(dir_name) do      
      files = IO.popen("find . -type f").readlines.map(&:chomp)
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
