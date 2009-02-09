class FileCollection < Userfile 
  #TODO: everything here 
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
    end
    
    File.unlink(directory + self.name) if File.file?(directory + self.name) 
    
    self.name = collection_name
    self.size = self.list_files.size
    self.save
  end

  def content=(newcontent)
    @content = newcontent
    @content
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
  
  def format_size
    "#{self.size} files" 
  end
  
  def after_destroy
    self.delete_content
  end
  
end
