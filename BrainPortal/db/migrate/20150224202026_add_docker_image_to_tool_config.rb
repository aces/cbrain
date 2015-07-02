class AddDockerImageToToolConfig < ActiveRecord::Migration
  def change
    add_column :tool_configs, :docker_image, :string
  end
end
