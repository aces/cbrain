class AddContainerIndexToToolConfigs < ActiveRecord::Migration
  def change
    add_column :tool_configs, :container_index_location, :string
  end
end
