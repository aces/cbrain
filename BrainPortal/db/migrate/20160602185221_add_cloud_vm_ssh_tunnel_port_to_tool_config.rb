class AddCloudVmSshTunnelPortToToolConfig < ActiveRecord::Migration
  def change
    add_column :tool_configs, :cloud_vm_ssh_tunnel_port, :int
  end
end
