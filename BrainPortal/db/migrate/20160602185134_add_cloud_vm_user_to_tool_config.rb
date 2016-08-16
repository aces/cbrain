class AddCloudVmUserToToolConfig < ActiveRecord::Migration
  def change
    add_column :tool_configs, :cloud_vm_user, :string
  end
end
