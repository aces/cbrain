class RemoveColumsFromToolConfigs < ActiveRecord::Migration[5.0]
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
