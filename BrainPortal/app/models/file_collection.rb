
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
  
  #extract a collection from an archive
  def extract_collection
    collection_name = self.name.split('.')[0]
    directory = Pathname.new(CBRAIN::Filevault_dir) + self.user.login + collection_name
    
    Dir.mkdir(directory) unless File.directory?(directory)
    self.save_content(directory)
    
    files = []
    Dir.chdir(directory) do
      if self.name =~ /\.tar(\.gz)?$/
        `tar xvf #{self.name}`
      else
        `unzip #{self.name}`
      end
      
      # if common_base = self.get_common_base(self.list_files)
      #         File.rename(common_base, ".")
      #       end
    end
    
    File.unlink(directory + self.name) if File.file?(directory + self.name) 
    
    
    
    self.name = collection_name
    
    
    self.flatten
    
    self.size = self.list_files.size
    
    self.save
  end
  
  def merge_collections(file_ids)
    userfiles = Userfile.find(file_ids)
    
    full_names = userfiles.inject([]){|list, file| list += file.list_files}    
    raw_names = full_names.map{ |file| file.sub(/^.+\//, "") }
    
    unless raw_names.uniq == raw_names
      return :collision
    end
    
    suffix = Time.now.to_i
    
    while self.user.userfiles.any?{ |f| f.name == "Collection-#{suffix}"}
      suffix += 1
    end
    
    self.name = "Collection-#{suffix}"
    
    Dir.mkdir(self.vaultname) unless File.directory?(self.vaultname)
    
    userfiles.each do |file|
      if file.is_a? FileCollection
        `cp -n -R #{file.vaultname}/ #{self.vaultname}`
      else
        `cp -n #{file.vaultname} #{self.vaultname}`
      end
    end
    
    self.size = self.list_files.size
    
    if self.save
      :success
    else
      :failure
    end
  end

  def content=(newcontent)
    @content = newcontent
    @content
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
  
  def save_content(directory)
    return if @content.nil?
    finalname =  directory + self.name 
    tmpname   = directory + (self.name + '.tmp')
    out = File.open(tmpname, "w") { |io| io.write(@content) }
    File.rename(tmpname,finalname)
  end

  def delete_content
    vaultname = self.vaultname
    
    self.list_files.each do |f|
      file = self.user.vault_dir + f
      File.unlink(file) if File.file?(file)      
    end
    
    self.list_dirs.each do |d|
      dir = self.user.vault_dir + d
      Dir.rmdir(dir) if File.directory?(dir)
    end
    
    Dir.rmdir(vaultname) if File.directory?(vaultname)
    @content=nil 
  end
  
  def list_files    
    Dir.chdir(self.user.vault_dir) do
      @file_list ||= `find #{self.name} -type f`.split("\n")
    end
  end
  
  def list_dirs
    Dir.chdir(self.user.vault_dir) do
      @dir_list ||= `find #{self.name} -type d`.split("\n").reverse
    end
  end
  
  #format size for display
  def format_size
    "#{self.size} files" 
  end
  
  def after_destroy
    self.delete_content
  end
    
  # remove common root from a directory structure.
  def flatten
    dir_name = self.vaultname

    Dir.chdir(dir_name) do

      files = `find . -type f`.split("\n")

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
