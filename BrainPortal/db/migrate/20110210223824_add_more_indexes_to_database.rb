
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

class AddMoreIndexesToDatabase < ActiveRecord::Migration
  def self.up
    add_index    :userfiles,       :format_source_id
    add_index    :userfiles,       :group_id

    add_index    :cbrain_tasks,    :group_id

    add_index    :data_providers,  :user_id
    add_index    :data_providers,  :group_id
    add_index    :data_providers,  :type

    add_index    :tags,            :user_id

    add_index    :messages,        :user_id

    add_index    :custom_filters,  :type

    add_index    :tools,           :user_id
    add_index    :tools,           :group_id
    add_index    :tools,           :category
    add_index    :tools,           :cbrain_task_class

    add_index    :tool_configs,    :tool_id
    add_index    :tool_configs,    :bourreau_id

    add_index    :tags_userfiles,  :tag_id
    add_index    :tags_userfiles,  :userfile_id

    add_index    :groups_users,    :group_id
    add_index    :groups_users,    :user_id

    add_index    :bourreaux_tools, :bourreau_id
    add_index    :bourreaux_tools, :tool_id
  end

  def self.down
    remove_index :userfiles,       :format_source_id
    remove_index :userfiles,       :group_id

    remove_index :cbrain_tasks,    :group_id

    remove_index :data_providers,  :user_id
    remove_index :data_providers,  :group_id
    remove_index :data_providers,  :type

    remove_index :tags,            :user_id

    remove_index :messages,        :user_id

    remove_index :custom_filters,  :type

    remove_index :tools,           :user_id
    remove_index :tools,           :group_id
    remove_index :tools,           :category
    remove_index :tools,           :cbrain_task_class

    remove_index :tool_configs,    :tool_id
    remove_index :tool_configs,    :bourreau_id

    remove_index :tags_userfiles,  :tag_id
    remove_index :tags_userfiles,  :userfile_id

    remove_index :groups_users,    :group_id
    remove_index :groups_users,    :user_id

    remove_index :bourreaux_tools, :bourreau_id
    remove_index :bourreaux_tools, :tool_id
  end

end

