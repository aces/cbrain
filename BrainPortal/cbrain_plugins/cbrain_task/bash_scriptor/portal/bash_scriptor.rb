
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

  Revision_info=CbrainFileRevision[__FILE__]

  # RDOC comments here, if you want, although the method
  # is created with #:nodoc: in this template.
  def self.default_launch_args #:nodoc:
    # Example: { :my_counter => 1, :output_file => "ABC.#{Time.now.to_i}" }
    { :num_files_per_task => 1 }
  end

  # RDOC comments here, if you want, although the method
  # is created with #:nodoc: in this template.
  def before_form
    params = self.params
    ids    = params[:interface_userfile_ids]
    cb_error "This task can ONLY be launched by the administrator.\n" unless self.user == User.admin
    ""
  end

  # RDOC comments here, if you want, although the method
  # is created with #:nodoc: in this template.
  def after_form #:nodoc:
    params = self.params
    #cb_error "Some error occurred."
    cb_error "This task can ONLY be launched by the administrator.\n" unless self.user == User.admin
    params_errors.add(:num_files_per_task, "must be a number greater than 1.") if params[:num_files_per_task].blank? || params[:num_files_per_task].to_i < 1
    ""
  end

  def final_task_list #:nodoc:
    params     = self.params
    file_ids   = (params[:interface_userfile_ids] || []).dup
    ser_factor = (params[:num_files_per_task].presence || 1).to_i

    task_list = []

    while file_ids.size > 0
      task   = self.clone
      subset = file_ids.slice!(0,ser_factor)
      task.params[:interface_userfile_ids] = subset
      task.description  = task.description.blank? ? "" : task.description.strip + "\n\n"
      task.description += subset.size == 1 ? "(1 file)" : "(#{subset.size} files)"
      task_list << task
    end

    task_list
  end

  def untouchable_params_attributes #:nodoc:
    { :output_userfile_ids => true }
  end

end

