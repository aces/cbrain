
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
# along with this program. If not, see https://www.gnu.org/licenses
#

class AddReverseNetworkParamsToRemoteResource < ActiveRecord::Migration[5.0]

  def change
    add_column :remote_resources, :active_resource_control_port,          :integer, :after => :ssh_control_rails_dir

    add_column :remote_resources, :use_reverse_service,                   :boolean, :default => false, :null => false, :after => :active_resource_control_port
    add_column :remote_resources, :reverse_service_user,                  :string,  :after => :use_reverse_service
    add_column :remote_resources, :reverse_service_host,                  :string,  :after => :reverse_service_user
    add_column :remote_resources, :reverse_service_port,                  :string,  :after => :reverse_service_host
    add_column :remote_resources, :reverse_service_db_socket_path,        :string,  :after => :reverse_service_port
    add_column :remote_resources, :reverse_service_ssh_agent_socket_path, :string,  :after => :reverse_service_db_socket_path
  end

end

