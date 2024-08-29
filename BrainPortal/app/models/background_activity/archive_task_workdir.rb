
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

# Archive a CBRAIN task.
#
# Options: archive_data_provider_id.
#
# Must be run on a Bourreau only.
class BackgroundActivity::ArchiveTaskWorkdir < BackgroundActivity::TerminateTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def process(item)
    super(item) # invokes the terminate code; will skip tasks that don't need to be terminated
    cbrain_task  = CbrainTask.where(:bourreau_id => CBRAIN::SelfRemoteResourceId).find(item)
    dest_dp_id   = self.options[:archive_data_provider_id] # can be nil
    nozip        = self.options[:nozip]
    ok           = cbrain_task.archive_work_directory(nozip)                              if dest_dp_id.blank?
    ok           = cbrain_task.archive_work_directory_to_userfile(dest_dp_id.to_i, nozip) if dest_dp_id.present?
    return [ true,  "Archived" ] if   ok
    return [ false, "Skipped"  ] if ! ok
  end

  def prepare_dynamic_items
    populate_items_from_task_custom_filter
  end

end

