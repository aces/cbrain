class AddSingularityhubImageToToolConfig < ActiveRecord::Migration
  def change
    add_column :tool_configs, :singularityhub_image, :string
  end
end
