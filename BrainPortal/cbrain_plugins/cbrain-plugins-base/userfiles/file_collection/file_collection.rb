
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

require 'fileutils'
require 'find'

#This model is meant to represent an arbitrary collection files (which
#may or may not contain subdirectories) registered as a single entry in
#the userfiles table.
class FileCollection < Userfile

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  validates :type, :subclass => { :root_class => FileCollection }

  has_viewer :name => 'Directory Content', :partial => :file_collection, :if => :is_locally_synced?

  has_content :collection_file

  # Basename of the archiving mechanism's tar file.
  CBRAIN_ARCHIVE_CONTENT_BASENAME="CBRAIN_ArchivedContent.tar.gz"

  def self.valid_file_classes #:nodoc:
    @valid_file_classes ||= [FileCollection] + FileCollection.descendants
  end

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
      escaped_tmparchivefile = archive_file_name.to_s.bash_escape
      if archive_file_name =~ /(\.tar.gz|\.tgz)$/i
        system("gunzip < #{escaped_tmparchivefile} | tar xf -")
      elsif archive_file_name =~ /\.tar$/i
        system("tar -xf #{escaped_tmparchivefile}")
      elsif archive_file_name =~ /\.zip$/i
        system("unzip #{escaped_tmparchivefile}")
      else
        cb_error "Cannot extract files from archive with unknown extension '#{archive_file_name}'"
      end
    end

    self.remove_unwanted_files

    self.sync_to_provider
    self.set_size!
    self.save

    true
  end

  # Calculates and sets the size attribute (active recount forced)
  def set_size!
    allfiles       = self.list_files(:all, :regular) || []
    self.size      = allfiles.inject(0){ |total, file_entry|  total += ( file_entry.size || 0 ); total }
    self.num_files = allfiles.size
    self.save!

    true
  end


  #Merge the collections and files in the array +userfiles+
  #Returns the status of the merge as a *symbol*:
  #[*success*] if the merge is successful.
  #[*collision*] if the collections share common file names (the merge is aborted in this case).
  def merge_collections(userfiles)

    # Check for collision
    full_names = userfiles.inject([]){|list, file| list += file.list_files.map(&:name)}

    unless full_names.uniq.size == full_names.size
      return :collision
    end

    self.cache_prepare
    destname  = self.cache_full_path.to_s
    Dir.mkdir(destname) unless File.directory?(destname)

    total_size = 0
    total_num_files  = 0

    userfiles.each do |file|

      file.sync_to_cache
      filename = file.cache_full_path.to_s
      total_size += file.size
      if file.is_a? FileCollection
        total_num_files += file.num_files
      else
        total_num_files += 1
      end

      FileUtils.cp_r(filename,destname) # file or dir INTO dir
    end

    self.size      = total_size
    self.num_files = total_num_files

    self.save!
    self.sync_to_provider
    :success
  end


  # Mathieu Desrosiers
  # Returns an array of the relative paths to first level subdirectories contained in this collection.
  # this function only for usage in spmbatch, feel free to contact me if you would like to remove it.
  def list_first_level_dirs
    return @dir_list if @dir_list
    Dir.chdir(self.cache_full_path.parent) do
      IO.popen("find #{self.name.bash_escape} -type d -mindepth 1 -maxdepth 1 -print") do |fh|
        @dir_list = fh.readlines.map(&:chomp)
      end
      @dir_list.sort! { |a,b| a <=> b }
    end
  end

  # Mathieu Desrosiers
  # remove unwanted .DS_Store file and "._" files from a packages if there is some
  # this function may be harmfull and only matter if the archive came from a MACOSX archive
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

  # Content loader
  def collection_file(path_string)
    return nil unless self.list_files.find { |f| f.name == path_string }

    path = self.cache_full_path.parent + path_string

    return nil unless File.exist?(path) and File.readable?(path) and !(File.directory?(path) || File.symlink?(path) )

    path
  end

  ##################################################################
  # FileCollection Archiving API
  ##################################################################

  # This method will archive a FileCollection in-situ and
  # update its content on the DataProvider side. It creates
  # a .tar.gz file of the content of the FileCollection. The tar
  # file will be left in the directory itself,
  # and all other files will be removed.
  # Restoring the state of the workdir can be performed with
  # provider_unarchive().
  # Returns an empty string if everithing is ok otherwise returns
  # the error message.
  def provider_archive()

    # Keep updated_at value in order to reset it at the end of method
    updated_at_value = self.updated_at

    return "" if self.archived?

    self.sync_to_cache
    # Just to check that file properties are OK; raise exception otherwise.
    # We don't call sync_to_provider directly in order to avoid the cost of set_size!
    self.data_provider.sync_to_provider(self)

    # Define some temp files
    cache_full_path    = self.cache_full_path.to_s   # where we will work
    temp_tar_file      = "T_#{Process.pid}_#{Time.now.to_i}_#{CBRAIN_ARCHIVE_CONTENT_BASENAME}"
    tar_capture        = "/tmp/tar.capture.#{Process.pid}.out"

    Dir.chdir(cache_full_path) do
      SyncStatus.ready_to_modify_cache(self) do

        return "" if self.archived? # In case another process has already archived it while we waited.
        return "Archive file already exists, yet file not marked as archived?" if File.exist?(CBRAIN_ARCHIVE_CONTENT_BASENAME)

        # Execute tar command
        system("tar -czf #{temp_tar_file.bash_escape} --exclude #{temp_tar_file.bash_escape} . </dev/null >'#{tar_capture}' 2>&1")

        # Verify if tar is OK
        error_status = $?.to_s
        out          = File.read(tar_capture) rescue ""
        message      = verify_tar_execution(out,error_status,self.name,temp_tar_file)
        return message if message.present?

        begin
          File.rename(temp_tar_file, CBRAIN_ARCHIVE_CONTENT_BASENAME)
        rescue
          File.unlink(CBRAIN_ARCHIVE_CONTENT_BASENAME)
          return "Cannot copy tar file in collection '#{self.name}'"
        end

        # Remove all files
        system("chmod","-R","u+rwX",".") # uppercase X mode affects only directories
        entries = Dir.entries(".").reject { |e| e == '.' || e == '..' || e == CBRAIN_ARCHIVE_CONTENT_BASENAME }
        entries.each { |e| FileUtils.rm_rf(e) rescue true }

      end
    end

    self.meta[:before_archiving_size]      = self.size
    self.meta[:before_archiving_num_files] = self.num_files
    self.sync_to_provider
    self.cache_erase
    self.archived = true
    self.save!

    "" # everything OK
  rescue => ex
    File.unlink(temp_tar_file) rescue true
    return "Archiving process exception: #{ex.class} #{ex.message}"
  ensure
    File.unlink(tar_capture)   rescue true
    File.unlink(temp_tar_file) rescue true
    # Reset update timestamp
    self.update_column(:updated_at, updated_at_value)
  end

  # This method will desarchive a FileCollection in-situ and
  # update its content on the DataProvider side.
  # Return an empty string if everithing is ok otherwise return
  # the error message.
  def provider_unarchive

    return "" if ! self.archived?

    self.sync_to_cache
    # Just to check that file properties are OK; raise exception otherwise.
    # We don't call sync_to_provider directly in order to avoid the cost of set_size!
    self.data_provider.sync_to_provider(self)

    # Define a temp file
    cache_full_path = self.cache_full_path.to_s
    tar_capture     = "/tmp/tar.capture.#{Process.pid}.out"

    Dir.chdir(cache_full_path) do

      if ! File.exist?(CBRAIN_ARCHIVE_CONTENT_BASENAME)
        return "Cannot unarchive: tar archive does not exist in collection."
      end

      SyncStatus.ready_to_modify_cache(self) do

        return "" if !self.archived? # In case another process has already unarchived it while we waited.

        # Execute tar command
        system("tar -xzf #{CBRAIN_ARCHIVE_CONTENT_BASENAME} </dev/null >'#{tar_capture}' 2>&1")

        # Verify if tar is OK
        error_status = $?.to_s
        out          = File.read(tar_capture) rescue ""
        message      = verify_tar_execution(out,error_status,self.name)
        return message if !message.blank?

        # Remove the archive
        File.unlink(CBRAIN_ARCHIVE_CONTENT_BASENAME) rescue true
      end
    end

    self.meta[:before_archiving_size]      = nil
    self.meta[:before_archiving_num_files] = nil
    self.sync_to_provider
    self.archived = false
    self.save!

    "" # everything OK

    rescue => ex
      return "Unarchiving process exception: #{ex.class}"
    ensure
      File.unlink(tar_capture) rescue true
  end

  def verify_tar_execution(out,error_status,userfile_name,temp_tar_file=nil) #:nodoc:

    # Remove some common warnings
    # "tar: something.sock: socket ignored"
    # "tar: .: file changed as we read it"
    out.gsub!(/tar.*ignored|tar.*changed as we read it/,"")

    if ! out.blank?
      outlines = out.split(/\n/)
      if outlines.size > 10
        outlines[10..99999] = [ "(#{outlines.size-10} more lines)" ]
      end
      return  "Error with tar command: output of tar for #{userfile_name}:\n#{outlines.join("\n")}"
    end

    # Parse error status
    if error_status =~ /exit\s+(\d+)/
      return "Error with tar command: tar exited with return code #{$1}" if $1.to_i > 1
    elsif error_status =~ /signal\s+(\d+)/
      return "Error with tar command: tar exited with signal #{$1}"
    end

    if temp_tar_file && ( ! File.file?(temp_tar_file) || File.size(temp_tar_file) == 0 )
      return "Error creating TAR archive: no file found after command, and no output? for #{userfile_name}.\n"
    end

    "" # empty string means all OK
  end

end


