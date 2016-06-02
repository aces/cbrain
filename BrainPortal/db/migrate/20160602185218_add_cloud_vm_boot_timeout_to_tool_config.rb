class AddCloudVmBootTimeoutToToolConfig < ActiveRecord::Migration
  def change
    add_column :tool_configs, :cloud_vm_boot_timeout, :int
  end
end
