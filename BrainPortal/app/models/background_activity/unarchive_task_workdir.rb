
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

# Unarchive CBRAIN tasks.
#
# Must be run on a Bourreau only.
class BackgroundActivity::UnarchiveTaskWorkdir < BackgroundActivity

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  before_save :must_be_on_bourreau!

  validates_dynamic_bac_presence_of_option :task_custom_filter_id

  def process(item)
    cbrain_task = CbrainTask.where(:bourreau_id => CBRAIN::SelfRemoteResourceId).find(item)
    if cbrain_task.archived_status == :userfile # automatically guess which kind of unarchiving to do
      ok = cbrain_task.unarchive_work_directory_from_userfile
    else
      ok = cbrain_task.unarchive_work_directory
    end
    return [ true,  nil          ] if   ok
    return [ false, "Skipped"    ] if ! ok
  end

  def prepare_dynamic_items
    populate_items_from_task_custom_filter
  end

end

