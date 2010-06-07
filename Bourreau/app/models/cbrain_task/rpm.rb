
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
   # - ./output/       -- will have 3 result files with BP, R1 and k2.
   def setup #:nodoc:
      task_type = self.params[:rpm_task_type]

      if task_type == 'subtask' and params[:subtask_id] == 0
         cpt_ref_file_id   = self.params[:cpt_ref_file_id]
         img_collection_id = self.params[:img_collection_id]

         cpt_ref_file    = Userfile.find(cpt_ref_file_id)
         img_collection  = Userfile.find(img_collection_id)

         cpt_ref_file.sync_to_cache
         img_collection.sync_to_cache

         File.symlink(cpt_ref_file.cache_full_path.to_s, "ref.cpt")
         File.symlink(img_collection.cache_full_path.to_s, "inputImage")

         Dir.mkdir("output", 0700)
      end

      true
   end

   def cluster_commands #:nodoc:
      task_type  = self.params[:rpm_task_type]

      if task_type=='combiner'
         command_line_bp = "cat"
         command_line_r1 = "cat"
         command_line_k2 = "cat"

         number_of_subtasks = self.params[:number_of_subtasks]
         # Combiner task
         number_of_subtasks.times { |i|
            command_line_bp += " part_#{i}_RPM_BP.i"
            command_line_r1 += " part_#{i}_RPM_R1.i"
            command_line_k2 += " part_#{i}_RPM_k2.i"
         }
         command_line_bp += " > ./output/rpm_out_bp.i"
         command_line_r1 += " > ./output/rpm_out_r1.i"
         command_line_k2 += " > ./output/rpm_out_k2.i"
         return ["#{command_line_bp}",
                 "#{command_line_r1}",
                 "#{command_line_k2}"]
      else
         command_line = ""
         image_filename     = self.params[:image_filename]
         subtask_id         = self.params[:subtask_id]
         number_of_subtasks = self.params[:number_of_subtasks]
         # Regular subtask. /home/azoubare/parallelRPM/bin
         # $RPM_DIR is a hopefully temporary solution to the problem with
         # compiled MATLAB scripts where some compiler versions produce code that
         # requires absolute path to be specified when running the executable.
         command_line += "$RPM_DIR/RPM_SUBTASK #{subtask_id} #{number_of_subtasks} 'ref.cpt' './inputImage/#{image_filename}'"
         self.addlog("RPM task command line: #{command_line}")
         return ["#{command_line}"]
#TODO: Remove this!
#        return ["sleep 5","date > part_#{subtask_id}_RPM_BP.i"]
      end
   end

   def recover_from_cluster_failure()
      true
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

         unless (  File.exists?("./output/rpm_out_bp.i") ||
                   File.exists?("./output/rpm_out_r1.i") ||
                   File.exists?("./output/rpm_out_k2.i")
                )
            self.addlog("Could not find result file(s).")
            return false
         end

         results_collection = FileCollection.new(
            :name             => self.params[:output_filename],
            :user_id          => user_id,
            :group_id         => group_id,
            :data_provider_id => self.params[:data_provider_id],
            :task             => "RPM"
         )

         unless results_collection.save
            self.addlog("Could not save result files '#{results_collection.name}'.")
            return false
         end

         results_collection.cache_copy_from_local_file("./output")
         results_collection.move_to_child_of(cpt_ref_file)

         return true
      else
         # Nothing to save.
         return true
      end
  end

end

