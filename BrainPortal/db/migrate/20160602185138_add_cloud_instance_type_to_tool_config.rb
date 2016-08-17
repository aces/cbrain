class AddCloudInstanceTypeToToolConfig < ActiveRecord::Migration
  def change
    add_column :tool_configs, :cloud_instance_type, :string
  end
end
