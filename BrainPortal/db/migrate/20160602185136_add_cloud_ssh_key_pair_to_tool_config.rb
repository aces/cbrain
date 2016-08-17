class AddCloudSshKeyPairToToolConfig < ActiveRecord::Migration
  def change
    add_column :tool_configs, :cloud_ssh_key_pair, :string
  end
end
