
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
#
# CBRAIN Project
#
# ClusterTask Model BashScriptor
#

# A subclass of ClusterTask to run BashScriptor.
class CbrainTask::BashScriptor < ClusterTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  include RestartableTask
  include RecoverableTask

  def job_walltime_estimate #:nodoc:
    params       = self.params
    file_ids     = params[:interface_userfile_ids].presence || []
    est_per_id   = params[:time_estimate_per_file].presence || 60

    total = (file_ids.size + 1) * est_per_id.to_i
    total = 60 if total < 60
    return total
  end

  def setup #:nodoc:
    params       = self.params
    file_ids = params[:interface_userfile_ids] || []
    file_ids.each do |id|
      file = Userfile.find(id)
      self.results_data_provider_id ||= file.data_provider_id
      file.sync_to_cache
    end
    return true
  end

  def cluster_commands #:nodoc:
    params       = self.params
    file_ids     = params[:interface_userfile_ids] || []
    File.unlink(self.stdout_cluster_filename) rescue nil # needed in case of retries

    raw_text     = params[:bash_script]
    raw_text.tr!("\r","") # text areas have CRs in line terminators, yuk!
    raise "No bash script?!?" if raw_text.blank?

    phase_1_text = raw_text.dup.pattern_substitute(
      {
        'cbrain_task_cluster_workdir' => self.full_cluster_workdir.to_s.bash_escape,
        'cbrain_task_id'              => self.id,
        'cbrain_task_run_number'      => self.run_number,
        'cbrain_task_run_id'          => self.run_id,
        'cbrain_cluster_name'         => self.bourreau.name,
        'cbrain_userfile_list_size'   => file_ids.size
      },
      :leave_unset => true
    )

    final_script = []

    file_ids.each_with_index do |id,cnt|
      file = Userfile.find(id)
      full_touch_file = self.full_cluster_workdir.to_s + "/" + self.qsub_script_basename.to_s + "-#{id}"
      File.unlink(full_touch_file) rescue true # for restarts
      txt  = phase_1_text.dup.pattern_substitute(
        {
          'cbrain_userfile_id'              => id,
          'cbrain_userfile_name'            => file.name,
          'cbrain_userfile_cache_full_path' => file.cache_full_path.to_s.bash_escape,
          'cbrain_touch_when_completed'     => full_touch_file.to_s.bash_escape,
          'cbrain_userfile_list_counter'    => cnt+1
        },
        :leave_unset => true
      )
      final_script << "\n# ===============================================================\n"
      final_script <<   "# Script for file ID #{id} named #{file.name}\n"
      final_script <<   "# ===============================================================\n"
      final_script << "\n"
      final_script << "cd #{self.full_cluster_workdir.to_s.bash_escape}\n"
      final_script << "\n"
      final_script << txt # multi line scripts are OK in array.
      final_script << "\n\n"
    end

    return final_script
  end

  def save_results #:nodoc:
    params       = self.params
    stdout       = File.read(self.stdout_cluster_filename) rescue ""
    out_ids      = []

    # Check conventional 'touch' files that mean 'completed on cluster'
    file_ids     = params[:interface_userfile_ids] || []
    file_ids.each do |id|
      full_touch_file = self.full_cluster_workdir.to_s + "/" + self.qsub_script_basename.to_s + "-#{id}"
      unless File.exists?(full_touch_file)
        self.addlog("Could not find the special file that indicates successful completion for file '#{id}'.")
        self.addlog("Maybe you forgot to add 'touch {cbrain_touch_when_completed}' to your script?")
        return false
      end
    end

    # Parse the output, finding the special pleading sentences.
    self.addlog("Searching standard output for magic sentence 'Please CBRAIN...'")
    magic_regex = Regexp.new(
        'Please\s+CBRAIN,\s+save\s+'      +     #  Please CBRAIN save
        '(\S+)'                           +     #  [filepath]                #1
        '\s+to\s+'                        +     #  to
        '([A-Z][\w]+)'                    +     #  [userfile_type]           #2
        '\s+named\s+'                     +     #  named
        '(\S+)'                           +     #  [userfile_name]           #3
        '(\s+and\s+then\s+delete\s+it)?'  +     #  and then delete it        #4, optional
        '(?:\s+as\s+child\s+of\s+(\d+))?' +     #  as child of [userfile_id] #5, optional
        '(\s+and\s+then\s+delete\s+it)?'        #  and then delete it        #6, optional again
    )

    stdout.scan(magic_regex).each do |m|

      # Extract significant components
      src_path  = m[0]
      out_type  = m[1]
      out_name  = m[2]
      del_1     = m[3] # optional
      parent_id = m[4] # optional
      del_2     = m[5] # optional
      self.addlog("Saving: '#{src_path}' to '#{out_type}' named '#{out_name}'#{parent_id.present? ? " child of #{parent_id}" : ""}")

      # Create output file
      out_class = out_type.constantize
      cb_error "Type #{out_type} not a subclass of Userfile." unless out_class < Userfile
      cb_error "No file found for path #{src_path} ?"         unless File.exists?(src_path)
      out_userfile = safe_userfile_find_or_new(out_class, :name => out_name)
      out_userfile.user_id  = (params[:saved_files_user_id].presence  || self.user_id).to_i
      out_userfile.group_id = (params[:saved_files_group_id].presence || self.group_id).to_i
      out_userfile.save!
      out_userfile.cache_copy_from_local_file(src_path)

      # Erase source (optional)
      if (del_1.present? || del_2.present?) && self.path_is_in_workdir?(src_path)
        self.addlog("Removing source file.")
        FileUtils.rm_rf(src_path) rescue true
      end

      # Record logging info
      out_ids << out_userfile.id
      if parent_id.present?
        parent = Userfile.find(parent_id)
        out_userfile.move_to_child_of(parent)
        self.addlog_to_userfiles_these_created_these( parent, out_userfile )
      else
        self.addlog_to_userfiles_created( out_userfile )
      end

    end

    params[:output_userfile_ids] = out_ids

    return true
  end

end

