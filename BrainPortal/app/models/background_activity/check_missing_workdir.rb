
#
# CBRAIN Project
#
# Copyright (C) 2008-2024
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

# This action is created at boot time on a Bourreau, to check
# for missing task work directories and adjust the database.
class BackgroundActivity::CheckMissingWorkdir < BackgroundActivity

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Creates a scheduled object for checking the workdirs.
  # Returns the object.
  # Will not do it if an object already exists that was updated less
  # than 24 hours ago. In that case, returns nil.
  def self.setup!(remote_resource_id = CBRAIN::SelfRemoteResourceId)
    # Don't schedule a check if we've had one in the past 24 hours
    return nil if self.where(:remote_resource_id => remote_resource_id)
                      .where('updated_at > ?', 24.hours.ago)
                      .exists?

    # Create the scheduled object
    self.new(
      :user_id            => User.admin.id,
      :remote_resource_id => remote_resource_id,
      :status             => 'Scheduled',
      :start_at           => Time.now + 300.seconds,
    )
    .configure_for_dynamic_items!
    .save!
  end

  def process(task_id)
    task = CbrainTask.where(:bourreau_id => self.remote_resource_id).find(task_id)
    full = task.full_cluster_workdir
    return [ true, nil        ] if Dir.exists?(full.to_s)
    task.cluster_workdir      = nil
    task.cluster_workdir_size = nil
    task.workdir_archived     = false if task.workdir_archive_userfile_id.blank?
    task.save
    return [ true, "Adjusted" ]  # keyword used in after_last_item() below
  end

  def prepare_dynamic_items
    local_tasks_with_workdirs = CbrainTask
      .real_tasks
      .wd_present
      .not_shared_wd
      .where( :bourreau_id => self.remote_resource_id )

    self.items = local_tasks_with_workdirs.pluck(:id)
  end

  def after_last_item

    adjusted_task_ids = self.items.select.each_with_index do |task_id,idx|
      next task_id if messages[idx] == 'Adjusted'
    end
    return if adjusted_task_ids.blank?

    myself = self.remote_resource

    Message.send_message(self.user,
      :type          => :system,
      :header        => "Report of task workdir disappearances on '#{myself.name}'",
      :description   => "Some work directories of tasks have disappeared.",
      :variable_text => "Number of tasks: #{adjusted_task_ids.size}\n" +
                        "List of tasks:\n" + adjusted_task_ids.sort
                        .each_slice(8).map { |tids| tids.join(" ") }.join("\n"),
      :critical      => true,
      :send_email    => false
    ) rescue true
  end

end

