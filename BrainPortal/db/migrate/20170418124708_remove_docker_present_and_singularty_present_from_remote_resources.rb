
class RemoveDockerPresentAndSingulartyPresentFromRemoteResources < ActiveRecord::Migration
  def up
    Bourreau.all.each do |b|
      next if !b.docker_present? && !b.singularity_present?
      b.update_attribute(:docker_executable_name,      "docker")      if b.docker_present?      && b.docker_executable_name.blank?
      b.update_attribute(:singularity_executable_name, "singularity") if b.singularity_present? && b.singularity_executable_name.blank?
    end
    remove_column :remote_resources, :docker_present
    remove_column :remote_resources, :singularity_present
  end

  def down
    add_column :remote_resources, :docker_present, :boolean
    add_column :remote_resources, :singularity_present, :boolean
    Bourreau.reset_column_information
    Bourreau.all.each do |b|
      b.update_attribute(:docker_present,      b.docker_executable_name.present?)
      b.update_attribute(:singularity_present, b.singularity_executable_name.present?)
    end
  end
end
