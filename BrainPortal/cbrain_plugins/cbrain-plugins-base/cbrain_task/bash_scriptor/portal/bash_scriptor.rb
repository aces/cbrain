
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

# PortalTask model BashScriptor
class CbrainTask::BashScriptor < PortalTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def self.default_launch_args #:nodoc:
    {
      :num_files_per_task     => 1,   # only used for internal serializing on portal side
      :time_estimate_per_file => 60,  # in seconds
      :share_all_wds          => "0", # false
    }
  end

  def self.properties #:nodoc:
    {
      :no_presets       => true,
      :use_parallelizer => true
    }
  end

  def before_form #:nodoc:
    cb_error "This task can ONLY be launched by the administrator.\n" unless self.user.has_role? :admin_user
    return ""
  end

  def after_form #:nodoc:
    params = self.params
    #cb_error "Some error occurred."
    cb_error "This task can ONLY be launched by the administrator.\n" unless self.user.has_role? :admin_user
    if self.new_record? && (params[:num_files_per_task].blank? || params[:num_files_per_task].to_i < 1)
      params_errors.add(:num_files_per_task, "must be a number greater than 1.")
    end
    if ((params[:bash_script].presence || "") !~ /\{cbrain_touch_when_completed\}/)
      params_errors.add(:bash_script, "must include at least one instance of substitution of the keyword {cbrain_touch_when_completed}.")
    end
    return ""
  end

  def final_task_list #:nodoc:
    params     = self.params
    file_ids   = (params[:interface_userfile_ids] || []).dup
    ser_factor = (params[:num_files_per_task].presence || 1).to_i
    share_wds  = ((params[:share_all_wds].presence || "0").to_s == "1")
    tot_files  = file_ids.size

    task_list  = []

    offset_cnt = 0
    while file_ids.size > 0
      task   = self.dup # not .clone, as of Rails 3.1.10
      subset = file_ids.slice!(0,ser_factor)
      task.params[:interface_userfile_ids] = subset
      desc = task.description.blank? ? "" : task.description.strip + "\n\n"
      subset[0,4].each do |id|
        file = Userfile.find(id) rescue nil
        next unless file
        desc += file.name + "\n"
      end
      desc += "\n(#{subset.size} files"
      desc +=   ", range: #{offset_cnt+1}..#{offset_cnt+subset.size} of #{tot_files}" if tot_files > 1
      desc += ")\n"
      task.description = desc
      task.params.delete :num_files_per_task # keep it clean, as no longer needed.
      task.share_wd_tid = -1 if share_wds # this tells the framework that all tasks share the same wd
      task_list << task
      offset_cnt += ser_factor
    end

    return task_list
  end

  def base_zenodo_deposit #:nodoc:
    ZenodoClient::Deposit.new(
      :metadata => ZenodoClient::DepositMetadata.new(
        :title       => 'CBRAIN BashScriptor Task Outputs',
        :description => "Outputs of task #{self.bname_tid}",
      )
    )
  end

  def zenodo_outputfile_ids #:nodoc:
    params[:output_userfile_ids] || []
  end

  def untouchable_params_attributes #:nodoc:
    {
      :output_userfile_ids => true
    }
  end

end

