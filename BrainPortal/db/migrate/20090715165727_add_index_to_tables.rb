
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

class AddIndexToTables < ActiveRecord::Migration
  def self.up

    add_index :users,            :login
    add_index :users,            :role

    add_index :userfiles,        :name
    add_index :userfiles,        :user_id
    add_index :userfiles,        :type
    add_index :userfiles,        :data_provider_id

    add_index :groups,           :name
    add_index :groups,           :type

    add_index :remote_resources, :type

    add_index :tags,             :name

    add_index :user_preferences, :user_id

    add_index :custom_filters,   :user_id

  end

  def self.down

    remove_index :users,            :login
    remove_index :users,            :role

    remove_index :userfiles,        :name
    remove_index :userfiles,        :user_id
    remove_index :userfiles,        :type
    remove_index :userfiles,        :data_provider_id

    remove_index :groups,           :name
    remove_index :groups,           :type

    remove_index :remote_resources, :type

    remove_index :tags,             :name

    remove_index :user_preferences, :user_id

    remove_index :custom_filters,   :user_id

  end
end

