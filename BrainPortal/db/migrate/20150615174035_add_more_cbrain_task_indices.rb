
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

class AddMoreCbrainTaskIndices < ActiveRecord::Migration
  def change
    add_index :cbrain_tasks, [ :bourreau_id,         :status               ]
    add_index :cbrain_tasks, [ :bourreau_id,         :status,      :type   ]
    add_index :cbrain_tasks, [ :user_id,             :bourreau_id, :status ]
    add_index :cbrain_tasks, [ :group_id,            :bourreau_id, :status ]
    add_index :cbrain_tasks, [ :cluster_workdir_size                       ]
    add_index :cbrain_tasks, [ :workdir_archived                           ]
  end
end
