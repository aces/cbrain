
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

class AddIndexToTasks < ActiveRecord::Migration
  def self.up
    add_index    :cbrain_tasks, :type
    add_index    :cbrain_tasks, :user_id
    add_index    :cbrain_tasks, :bourreau_id
    add_index    :cbrain_tasks, :status
    add_index    :cbrain_tasks, :launch_time
  end

  def self.down
    remove_index :cbrain_tasks, :type
    remove_index :cbrain_tasks, :user_id
    remove_index :cbrain_tasks, :bourreau_id
    remove_index :cbrain_tasks, :status
    remove_index :cbrain_tasks, :launch_time
  end
end

