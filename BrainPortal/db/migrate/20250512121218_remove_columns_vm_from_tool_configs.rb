
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

class RemoveColumnsVmFromToolConfigs < ActiveRecord::Migration[5.0]
  def change
    remove_column :tool_configs, :cloud_disk_image, :string
    remove_column :tool_configs, :cloud_vm_user, :string
    remove_column :tool_configs, :cloud_ssh_key_pair, :string
    remove_column :tool_configs, :cloud_instance_type, :string
    remove_column :tool_configs, :cloud_job_slots, :integer
    remove_column :tool_configs, :cloud_vm_boot_timeout, :integer
    remove_column :tool_configs, :cloud_vm_ssh_tunnel_port, :integer
  end
end
