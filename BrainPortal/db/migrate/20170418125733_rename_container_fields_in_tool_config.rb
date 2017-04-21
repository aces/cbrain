
ToolConfig

class ToolConfig
  def container_rules
    true
  end
end


class RenameContainerFieldsInToolConfig < ActiveRecord::Migration
  def up

    # Record current information, before renaming
    with_docker_image                  = ToolConfig.order(:id).all.select { |tc| tc.docker_image.present? }
    with_singularityhub_image          = ToolConfig.order(:id).all.select { |tc| tc.singularityhub_image.present? }
    with_singularity_image_userfile_id = ToolConfig.order(:id).all.select { |tc| tc.singularity_image_userfile_id.present? }

    # Add/Rename columns
    add_column    :tool_configs, :containerhub_image_name,       :string
    add_column    :tool_configs, :container_engine,              :string
    rename_column :tool_configs, :singularity_image_userfile_id, :container_image_userfile_id

    ToolConfig.reset_column_information

    # Re-insert information in DB
    with_docker_image.each do |tc|
      tc = ToolConfig.find(tc.id)
      puts "Adjusting TC with docker_image: #{tc.id}"
      tc.containerhub_image_name = tc.docker_image
      tc.container_engine        = "Docker"
      tc.save!
    end

    with_singularityhub_image.each do |tc|
      tc = ToolConfig.find(tc.id)
      puts "Adjusting TC with singularityhub_image: #{tc.id}"
      tc.containerhub_image_name = tc.singularityhub_image
      tc.container_engine        = "Singularity"
      tc.save!
    end

    with_singularity_image_userfile_id.each do |tc|
      tc = ToolConfig.find(tc.id)
      puts "Adjusting TC with singularity_image_userfile_id: #{tc.id}"
      tc.container_engine = "Singularity"
      tc.save!
    end

    # Remove extra columns
    remove_column :tool_configs, :docker_image
    remove_column :tool_configs, :singularityhub_image
  end

  def down
    # Add/rename columns
    add_column    :tool_configs, :docker_image,                  :string
    add_column    :tool_configs, :singularityhub_image,          :string
    add_column    :tool_configs, :singularity_image_userfile_id, :integer

    ToolConfig.reset_column_information

    # Re-insert information in DB
    ToolConfig.order(:id).all.select { |tc| tc.container_engine.present? }.each do |tc|
      if    (tc.container_engine == "Docker")
        puts "Adjusting TC with docker_image: #{tc.id}"
        tc.docker_image                  = tc.containerhub_image_name
      elsif (tc.container_engine    == "Singularity")
        puts "Adjusting TC with singularity_image: #{tc.id}"
        tc.singularityhub_image          = tc.containerhub_image_name
        tc.singularity_image_userfile_id = tc.container_image_userfile_id
      end
      tc.save!
    end

    # Remove extra columns
    remove_column :tool_configs, :containerhub_image_name
    remove_column :tool_configs, :container_image_userfile_id
    remove_column :tool_configs, :container_engine
  end
end
