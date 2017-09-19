class AddContainerIndexToToolConfigs < ActiveRecord::Migration
  def self.up
    add_column :tool_configs, :container_index_location, :string
    ToolConfig.find_each do |tool|
      if tool.container_engine == "Singularity" && tool.containerhub_image_name.present?
        tmp = tool.containerhub_image_name.split('://') # Splits container image name based on singularity expected syntax
        tool.containerhub_image_name = tmp[-1] # The container will always be the last item in the list
        tool.container_index_location = tmp[0] + "://" if tmp.length == 2 # The index location will be default if none found, else the first element
      end
    end
  end

  def self.down
    ToolConfig.find_each do |tool|
      if tool.container_engine == "Singularity" && tool.container_index_location.present?
        tool.containerhub_image_name = tool.container_index_location + tool.containerhub_image_name
      end
    end
    remove_column :tool_configs, :container_index_location
  end
end
