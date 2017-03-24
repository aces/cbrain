class AddSingularityhubImageAndSingularityImageUserfileIdToToolConfig < ActiveRecord::Migration
  def change
    add_column :tool_configs, :singularityhub_image, :string
    add_column :tool_configs, :singularity_image_userfile_id, :integer
  end
end
