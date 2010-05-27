
#
# CBRAIN Project
#
# CbrainTask subclass
#
# Original author: Anton Zoubarev
#
# $Id$
#

#A subclass of CbrainTask::ClusterTask to run RPM.
class CbrainTask::Rpm < CbrainTask::ClusterTask

   Revision_info="$Id$"

   # Workdir structure:
   # - ./ref.cpt
   # - ./inputImage/   -- collection of hrrt frames and headers
   # - ./output/
   def setup #:nodoc:
      task_type = self.params[:rpm_task_type]

      if task_type == 'subtask' and params[:subtask_id] == 0
	 cpt_ref_file_id   = self.params[:cpt_ref_file_id]
	 img_collection_id = self.params[:img_collection_id]

	 cpt_ref_file    = Userfile.find(cpt_ref_file_id)
	 img_collection	 = Userfile.find(img_collection_id)

	 cpt_ref_file.sync_to_cache
	 img_collection.sync_to_cache

	 File.symlink(cpt_ref_file.cache_full_path.to_s, "ref.cpt")  
	 File.symlink(img_collection.cache_full_path.to_s, "inputImage")
        
         Dir.mkdir("output", 0700)  
      end

      true
   end

   def cluster_commands #:nodoc:
      command_line = ""
      task_type  = self.params[:rpm_task_type]

      if task_type=='combiner'
         number_of_subtasks = self.params[:number_of_subtasks]
         # Combiner task
	 command_line += "cat"
	 number_of_subtasks.times { |i| command_line += " part_#{i}_RPM_BP.i" }
         command_line += " > ./output/rpm_out.i"
      else
         image_filename     = self.params[:image_filename]
         subtask_id         = self.params[:subtask_id]
         chunk_size         = self.params[:chunk_size]      
         # Regular subtask. /home/azoubare/parallelRPM/bin
	 command_line += "RPM_SUBTASK #{subtask_id} #{chunk_size} 'ref.cpt' './inputImage/#{image_filename}'"
#TODO: Remove this!
#        return ["sleep 5","date > part_#{subtask_id}_RPM_BP.i"]
      end
    
      self.addlog("RPM task command line: #{command_line}")
      return ["#{command_line}"]
   end

   def save_results #:nodoc:
      task_type = self.params[:rpm_task_type]

      if task_type == 'combiner'
	 user_id = self.user_id
	 data_provider_id = self.params[:data_provider_id]
	 
	 # Use group id of one of the input files.
	 cpt_ref_file_id = self.params[:cpt_ref_file_id]
	 cpt_ref_file    = SingleFile.find(cpt_ref_file_id)
	 group_id        = cpt_ref_file.group_id 

	 unless (File.exists?("./output/rpm_out.i"))
	    self.addlog("Could not find result file rpm_out.i")
	    return false
	 end

	 result_file = SingleFile.new(
	    :name             => self.params[:output_filename],
	    :user_id          => user_id,
	    :group_id         => group_id,
	    :data_provider_id => self.params[:data_provider_id],
	    :task             => "RPM"
	 )

         unless result_file.save
            self.addlog("Could not save back result file '#{result_file.name}'.")
            return false
         end

         result_file.cache_copy_from_local_file("./output/rpm_out.i")

         return true    
      else
	 # Nothing to save. 
         return true          
      end      	   
  end

end


