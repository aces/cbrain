
#
# CBRAIN Project
#
# Copyright (C) 2008-2019
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

class AddIndexesToResourceUsage < ActiveRecord::Migration[5.0]
  def change

    # Main index on type
    add_index :resource_usage, :type

    # Additional indexes on (type, some_column)
    #
    #   ID                 TYPE                 NAME                     OTHERS
    #--------------------- -------------------- ------------------------ ------------------
    %i( user_id            user_type            user_login
        group_id           group_type           group_name
        userfile_id        userfile_type        userfile_name
        data_provider_id   data_provider_type   data_provider_name
        cbrain_task_id     cbrain_task_type                              cbrain_task_status
        remote_resource_id                      remote_resource_name
        tool_id                                 tool_name
        tool_config_id                          tool_config_version_name
    ).each do |col|
      add_index :resource_usage, [ :type, col ]
    end

    # Wow that was a lot of indexes. Or indicies. Or Indicii. Or octopii.

  end
end

