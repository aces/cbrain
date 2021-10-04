class AddDescriptorBasenameToToolConfigs < ActiveRecord::Migration[5.0]
  def change
    add_column :tool_configs, :boutiques_descriptor_path, :string
  end
end
