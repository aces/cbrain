
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

   include RestartableTask # This task is naturally restartable
   include RecoverableTask # This task is naturally recoverable

   # Workdir structure:
   # - ./ref.cpt
   # - ./inputImage/   -- collection of hrrt frames and headers
   # - ./output/       -- will have 3 result files with BP, R1 and k2.
   def setup #:nodoc:
      task_type = self.params[:rpm_task_type]

      cpt_ref_file_id   = self.params[:cpt_ref_file_id]
      img_collection_id = self.params[:img_collection_id]
      cpt_ref_file    = Userfile.find(cpt_ref_file_id)
      img_collection  = Userfile.find(img_collection_id)

      if task_type == 'subtask' and params[:subtask_id] == 0
         cpt_ref_file.sync_to_cache
         img_collection.sync_to_cache

         safe_symlink(cpt_ref_file.cache_full_path.to_s, "ref.cpt")
         safe_symlink(img_collection.cache_full_path.to_s, "inputImage")

         safe_mkdir("output", 0700)
      end

      params[:data_provider_id] = cpt_ref_file.data_provider_id if params[:data_provider_id].blank?

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
      end
   end

   def save_results #:nodoc:

     # Nothing to save if we're a worker
     task_type = self.params[:rpm_task_type]
     return true if task_type != 'combiner'

     user_id = self.user_id
     data_provider_id = self.params[:data_provider_id]

     # Use group id of one of the input files.
     cpt_ref_file_id   = self.params[:cpt_ref_file_id]
     img_collection_id = self.params[:img_collection_id]
     cpt_ref_file    = Userfile.find(cpt_ref_file_id)
     img_collection  = Userfile.find(img_collection_id)
     group_id        = cpt_ref_file.group_id

     unless (  File.exists?("./output/rpm_out_bp.i") ||
               File.exists?("./output/rpm_out_r1.i") ||
               File.exists?("./output/rpm_out_k2.i")
            )
       self.addlog("Could not find result file(s).")
       return false
     end

     results_collection = safe_userfile_find_or_new(FileCollection,
        :name             => self.params[:output_filename],
        :user_id          => user_id,
        :group_id         => group_id,
        :data_provider_id => self.params[:data_provider_id],
        :task             => "RPM"
     )

     unless results_collection.save
        self.addlog("Could not save result files '#{results_collection.name}'.")
        params.delete(:results_collection_id)
        return false
     end

     results_collection.cache_copy_from_local_file("output")
     results_collection.move_to_child_of(cpt_ref_file)

     params[:results_collection_id] = results_collection.id
     self.addlog_to_userfiles_these_created_these([ cpt_ref_file, img_collection ], [ results_collection ])

     return true
   end

end

