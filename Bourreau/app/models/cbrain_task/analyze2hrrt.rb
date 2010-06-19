#
# CBRAIN Project
#
# Class for running analyze to hrrt conversion.
#
# Original author: Anton Zoubarev
# Template author: Pierre Rioux
#
# $Id$
#

# This will call ana2hrrt command line tool which assumes the following:
#  - input is the collection(directory) of analyze images and headers
#  - file names has the following format: yadayada_frame_#_blah.i 
#A subclass of CbrainTask::ClusterTask to run analyze2hrrt.
class CbrainTask::Analyze2hrrt < CbrainTask::ClusterTask

  Revision_info="$Id$"

  include RestartableTask # This task is naturally restartable
  include RecoverableTask # This task is naturally recoverable

  def setup #:nodoc:
    begin
      collection_id = self.params[:analyze_collection_id]
      collection = Userfile.find(collection_id)      # RecordNotFound will be raised if nothing found?
      collection.sync_to_cache

      params[:data_provider_id] = collection.data_provider_id if params[:data_provider_id].blank?

      safe_symlink(collection.cache_full_path.to_s, "input")
  
      safe_mkdir("output", 0700)
      
      file_names = collection.list_files.map(&:name)
      # Use first file of a collection since the script itself will construct filename for a file with frame_0.
      file_base = File.basename(file_names[0], '.*')
      # We'll need it during cluster_commands stage.
      self.params[:file_base] = file_base
    rescue => e
      self.addlog("An error occured during AnalyzeToHRRT setup: #{e.message}")
      return false
    end
    true
  end

  # For reference ana2hrrt USAGE:
  # ana2hrrt -i inputFile -o [outputFile] -r [headerFile] -a [anaHeaderFile] -f NumFrames [-m]
  # This program will convert Analyze File(s) to HRRT File(s).
  # Options:
  #   -i inputFile: path/filename of Analyze input filename
  #   (optional)-o outputFile: path/filename of output HRRT filename, '_frame#' will be appended automatically to outputFilename
  #   (optional)-r headerFile: path/filename of HRRT header filename (dummy header file will be used if this field not set)
  #   (optional)-a anaHeaderFile: path/filename of Analyze header filename (only necessary if different from if different from inputFile name)
  #   -f NumFrames: enter total number of frames
  #   (optional)-m : process multi-frame file (default is single frame input set)
  # If no outputFile is specified then the output is generated in the current working directory
  def cluster_commands #:nodoc:
    file_base = self.params[:file_base]
    # Build command line
    command_line = "ana2hrrt" 
    command_line += " -i ./input/#{file_base}.img"
    #command_line += " -a ./input/#{file_base}.hdr"
    #command_line += " -o ./output/#{file_base}.i"
    #command_line += " -r ./output/#{file_base}.i.hdr"
    command_line += " -f #{self.params[:number_of_frames]}"
    command_line += " -m"                                     if self.params[:multiframe]          

    return [command_line]
  end
  
  # Helper method to get group id of the user executing the task.
  # TODO: maybe move it to super class.
  def get_user_group_id #:nodoc:
    user         = User.find(user_id)
    group_id     = SystemGroup.find_by_name(user.login).id
    return group_id
  end

  # Create new collection from files in ./output
  def save_results #:nodoc:
    begin
      analyze_collection_id = self.params[:analyze_collection_id]
      analyze_collection    = Userfile.find(analyze_collection_id)

      # Move results files into output directory.
      outputs = Dir.glob('*.{i,i.hdr}') || []
      if outputs.size == 0
        self.addlog("Cannot find outputfiles ?")
        return false
      end
      FileUtils.mv(outputs, './output') # NOT RESTARTABLE!

      file_collection = safe_userfile_find_or_new(FileCollection,
        :name             => params[:output_collection_name],
        :user_id          => self.user_id,
        :group_id         => get_user_group_id,
        :data_provider_id => params[:data_provider_id],
        :task             => "AnalyzeToHRRT"
      )
      file_collection.cache_copy_from_local_file("output")
      file_collection.save!
      file_collection.move_to_child_of(analyze_collection)
      self.addlog("Saved new collection #{params[:output_collection_name]}")

      params[:hrrt_collection_id] = file_collection.id
      self.addlog_to_userfiles_these_created_these([analyze_collection],[file_collection])

    rescue => e
      self.addlog("An exception was raised during save_results step of Analyze2HRRT task: #{e.message}")
      params.delete(:hrrt_collection_id)
      return false
    end
    true
  end

  def restart_at_post_processing #:nodoc:
    false #because of FileUtils.mv above
  end

end

