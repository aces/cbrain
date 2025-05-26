
#
# CBRAIN Project
#
# Copyright (C) 2008-2025
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

class EraseOldStartVmTool < ActiveRecord::Migration[5.0]

  def up
    Tool.where(:cbrain_task_class_name => 'CbrainTask::StartVM').delete_all
  end

  def down
    true
  end

end
