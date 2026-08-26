
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

# Update the recorded size of the workdirs of a set of tasks.
# Generally runs as part of a Bourreau boot sequence.
class BackgroundActivity::UpdateTaskWorkdirSize < BackgroundActivity

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def self.setup!(task_ids)
    ba = self.local_new(User.admin.id, task_ids, CBRAIN::SelfRemoteResourceId)
    ba.status   = 'Scheduled'
    ba.start_at = 5.minutes.from_now
    ba.save
  end
  # Returns the primary class of items the task targets
  def targets_model
    CbrainTask
  end


  def process(task_id)
    task = CbrainTask.where(:bourreau_id => CBRAIN::SelfRemoteResourceId).find(task_id)
    size = task.send(:update_size_of_cluster_workdir) rescue nil # it's a protected method
    self.options[:totsize] ||= 0
    self.options[:totsize]  += size if size
    self.options[:skipped] ||= 0
    self.options[:skipped]  += 1 if ! size
    return [ true, nil ] if size
    return [ false, 'Error' ]
  end

  def after_final_item
    myself  = self.remote_resource
    totsize = self.options[:totsize] || 0
    skipped = self.options[:skipped] || 0
    Message.send_message(User.admin,
      :type          => :system,
      :header        => "Report of task sizes refresh on '#{myself.name}'",
      :description   => "The disk space used by some tasks needed to be recomputed.",
      :variable_text => "Report:\n" +
                        "Number of tasks: #{self.items.size}\n" +
                        "Total size     : #{totsize} bytes\n" +
                        "Tasks skipped  : #{skipped} tasks",
      :critical      => true,
      :send_email    => false
    ) rescue true
  end

end

