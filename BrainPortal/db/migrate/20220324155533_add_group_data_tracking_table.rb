
#
# CBRAIN Project
#
# Copyright (C) 2008-2022
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

class AddGroupDataTrackingTable < ActiveRecord::Migration[5.0]
  def change

    # Data tracking flag
    add_column :groups, :track_usage, :boolean, :default => false, :null => false

    # Data tracking table
    nf  = { :null => false }
    nf0 = { :null => false, :default => 0 }
    create_table :data_usage do |t|

      t.integer :user_id, nf               # which user
      t.integer :group_id, nf              # which group/project
      t.string  :yearmonth, nf             # period: "2022-03"

      t.integer :views_count, nf0          # count the number of userfiles viewed during the period
      t.integer :views_numfiles, nf0       # sum of num_files for these views

      t.integer :downloads_count, nf0      # count the number of userfiles downloaded
      t.integer :downloads_numfiles, nf0   # sum of num_files for these downloads

      t.integer :task_setups_count, nf0    # count the number of userfiles used to setup tasks
      t.integer :task_setups_numfiles, nf0 # sum of num_files for these tasks

      t.integer :copies_count, nf0         # count the number of userfiles copied to other DPs
      t.integer :copies_numfiles, nf0      # sum of num_files for these copies

      t.timestamps
    end

  end
end
