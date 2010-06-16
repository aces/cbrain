#
# CBRAIN Project
#
# Asipro2minc subclass for running asipro2minc
#
# Original author: Anton Zoubarev
# Template author: Pierre Rioux
#
# $Id$
#

#A subclass of CbrainTask::ClusterTask to run asipro2minc.
class CbrainTask::Asipro2minc < CbrainTask::ClusterTask

  Revision_info="$Id$"

  include RestartableTask # This task is naturally restartable
  include RecoverableTask # This task is naturally recoverable

  def setup #:nodoc:
    begin
      collection_id = self.params[:asipro_collection_id]
      collection    = Userfile.find(collection_id)

      unless collection && collection.is_a?(FileCollection)
        self.addlog("Could not find active record entry for file collection #{collection_id}")
        return false
      end

      params[:data_provider_id] = collection.data_provider_id if params[:data_provider_id].blank?

      collection.sync_to_cache
      safe_symlink(collection.cache_full_path.to_s, "input")

      file_names = collection.list_files.map(&:name)
      file_name = File.basename(file_names[0])
      # We'll need this name during cluster_commands stage.
      self.params[:file_name] = file_name

      safe_mkdir("output",0700)
    rescue => e
      self.addlog("An error occured: #{e.message}")                    
      return false
    end
    true
  end

  # USAGE: asipro2minc inputFile [outputFile]
  # This program will convert ASIPRO file(s) to MINC format file(s).
  # Options:
  #    inputFile: path/filename of input filename"
  #    (optional)outputFile: path/filename of output filename, '_frame#' will be appended automatically to outputFilename"
  # If no outputFile is specified then the output is generated in the current working directory"
  def cluster_commands #:nodoc:
    [
      "asipro2minc input/#{params[:file_name]}"
    ]
  end
  
  def save_results #:nodoc:
    begin
      asipro_collection_id = self.params[:asipro_collection_id]
      asipro_collection    = Userfile.find(asipro_collection_id)

      # Move results files into output directory.
      FileUtils.mv(Dir.glob('*.mnc'), './output')

      minc_collection = safe_userfile_find_or_new(FileCollection,
          :name             => "#{asipro_collection.name}_#{Time.now.to_i}_MINC",
          :user_id          => self.user_id,
          :group_id         => asipro_collection.group_id,
          :data_provider_id => self.params[:data_provider_id],
          :task             => "AsiproToMinc"
        )
      minc_collection.cache_copy_from_local_file("output")
      minc_collection.save!
      minc_collection.move_to_child_of(asipro_collection)

      self.addlog("Saved new MINC collection #{minc_collection}")

    rescue => e
      # e.backtrace?
      self.addlog("An error occured: #{e.message}")
      return false      
    end
    true
  end

end

