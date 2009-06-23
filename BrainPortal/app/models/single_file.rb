
#
# CBRAIN Project
#
# Single file model
# Represents an entry in the userfile table that corresponds to a single file.
#
# Original author: Tarek Sherif
#
# $Id$
#

require 'fileutils'

class SingleFile < Userfile
  
  Revision_info="$Id$"
  
  #Extract files from an archive and register them in the db
  def extract

    archive_file_name = self.name                      # "abc.tar.gz" or "abc.zip"
    collection_name = archive_file_name.split('.')[0]  # "abc"
    self.name = collection_name

    tmparchivefile = "/tmp/#{$$}-#{archive_file_name}"
    escaped_tmparchivefile = tmparchivefile.gsub("'", "'\\\\''")
    File.open(tmparchivefile, "w") { |io| io.write(@content) }

    status = :success
    all_files = []
    successful_files = []
    failed_files = []
    nested_files = []
    
    if archive_file_name =~ /\.tar(\.gz)?$/i
      all_files = IO.popen("tar -tf #{escaped_tmparchivefile}").readlines.map(&:chomp)
    else
      all_files = IO.popen("unzip -l #{escaped_tmparchivefile}").readlines.map(&:chomp)[3..-3].map{ |line|  line.split[3]}
    end
    
    count = all_files.select{ |f| f !~ /\// }.size
    
    #max of 50 files can be added to the file list at a time.
    if count > 50
      File.unlink(tmparchivefile)
      return [:overflow, -1, -1, -1]
    end 
    
    workdir = tmparchivefile + ".workdir"
    Dir.mkdir(workdir)
    Dir.chdir(workdir) do
      if archive_file_name =~ /\.tar(\.gz)?$/
        system("tar -xvf '#{escaped_tmparchivefile}'")
      else
        system("unzip '#{escaped_tmparchivefile}'")
      end
   end

    all_files.each do |file_name|
      if Userfile.find_by_name(file_name)
        failed_files << file_name
      elsif file_name =~ /\//
        nested_files << file_name
      else
        successful_files << file_name
      end
    end
           
    Dir.chdir(workdir) do
      successful_files.each do |file|
        u = SingleFile.new(:tag_ids  => self.tag_ids)
        u.name             = file
        u.data_provider_id = self.data_provider_id
        u.user_id          = self.user_id
        u.group_id         = self.group_id
        unless u.save(false)
          status = :failed
        else
          u.cache_copy_from_local_file(file)
        end      
      end
    end

    File.unlink(tmparchivefile)
    FileUtils.remove_dir(workdir, true)
    
    [status, successful_files, failed_files, nested_files]
  end


  #format size for display in the view
  def format_size
    if self.size > 10**9
      "#{self.size/10**9} GB"
    elsif   self.size > 10**6
      "#{self.size/10**6} MB"
    elsif   self.size > 10**3
      "#{self.size/10**3} KB"
    else
      "#{self.size} bytes"     
    end 
  end

  ########################################################
  # CONTENT access methods
  ########################################################
  
  # Gets the content of the file; caches it in memory.
  # Consider using the provider's cache_readhandle() instead
  # of storing the whole content into memory, if you can.
  def content
    return @content unless @content.nil?
    self.cache_readhandle do |io|
      @content = io.read
    end
    @content
  end

  # Sets the content of the file in memory.
  # Consider using the provider's cache_writehandle() instead
  # of storing the whole content into memory, if you can.
  def content=(newcontent)
    @content = newcontent
    self.size = @content.size
    self
  end
  
  def save_content
    return if @content.nil?
    self.cache_writehandle do |io|
      io.write(@content)
    end
    @content=nil
    self
  end

  def delete_content
    @content=nil
    self.provider_erase
  end
  
  ########################################################
  # Lifecycle callbacks
  ########################################################
  
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
