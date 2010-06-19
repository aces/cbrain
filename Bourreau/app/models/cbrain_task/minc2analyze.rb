#
# CBRAIN Project
#
# CbrainTask subclass for running minc2analyze
#
# Original author: Anton Zoubarev
# Template author: Pierre Rioux
#
# $Id$
#

#A subclass of CbrainTask::ClusterTask to run minc2analyze.
class CbrainTask::Minc2analyze < CbrainTask::ClusterTask

  Revision_info="$Id$"

  include RestartableTask # This task is naturally restartable
  include RecoverableTask # This task is naturally recoverable

  def setup #:nodoc:
    begin
      collection_id = self.params[:minc_collection_id]
      collection = Userfile.find(collection_id)      # RecordNotFound will be raised if nothing found?
      collection.sync_to_cache
      safe_symlink(collection.cache_full_path.to_s, "input")
  
      safe_mkdir("output", 0700)
      
      file_names = collection.list_files.map(&:name)
      # Use first file of a collection since the script itself will construct filename for file with frame_0.
      file_name = File.basename(file_names[0])
      # We'll need it during cluster_commands stage.
      self.params[:file_name] = file_name

    rescue => e     
      self.addlog("An error occured during AnalyzeToHRRT setup: #{e.message}")
      return false
    end
    true
  end

  # USAGE: minc2ana -i inputFile -f NumFrames -m type
  # This program will convert MINC file(s) to ANALYZE file(s) that can be in 'multiple' or 'single' format.
  # Options: 
  #    -i inputFile: path/filename of input MINC image filename
  #    -f NumFrames: enter total number of frames
  #    -m type value can be either 0, 1 or 2, where 0 means convert single minc to single analyze, 1 means multiple minc
  #       files to single analyze file, 2 means multiple minc files to multiple analyze files
  # Output file is generated in the current working directory
  
  def cluster_commands #:nodoc:
    file_name = self.params[:file_name]
    # Build command line
    command_line = "minc2ana" 
    command_line += " -i ./input/#{file_name}"
    command_line += " -f #{self.params[:number_of_frames]}"
    command_line += " -m #{self.params[:type]}"          

    return [command_line]
  end
  
  def save_results #:nodoc:
    begin
      minc_collection_id = self.params[:minc_collection_id]
      minc_collection    = Userfile.find(minc_collection_id)

      # Move results files into output directory.
      FileUtils.mv(Dir.glob('*.{img,hdr}'), './output')

      file_collection = safe_userfile_find_or_new(FileCollection,
        :name             => params[:output_collection_name],
        :user_id          => self.user_id,
        :group_id         => get_user_group_id,
        :data_provider_id => params[:data_provider_id],
        :task             => "MincToAnalyze"
      )
      file_collection.cache_copy_from_local_file("output")
      file_collection.save!
      file_collection.move_to_child_of(minc_collection)
      self.addlog("Saved new collection #{params[:output_collection_name]}")
      params[:analyze_collection_id] = file_collection.id
      self.addlog_to_userfiles_these_created_these([ minc_collection ], [ file_collection ])
    rescue => e
      self.addlog("An exception was raised during save_results step of MincToAnalyze task: #{e.message}")
      params.delete(:analyze_collection_id)
      return false
    end
    true
  end

  # Helper method to get group id of the user executing the task.
  # TODO: maybe move it to super class.
  def get_user_group_id #:nodoc:
    user         = User.find(user_id)
    group_id     = SystemGroup.find_by_name(user.login).id
    return group_id
  end

end

