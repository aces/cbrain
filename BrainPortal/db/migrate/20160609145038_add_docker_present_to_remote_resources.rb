class AddDockerPresentToRemoteResources < ActiveRecord::Migration
  def change
    add_column :remote_resources, :docker_present, :boolean
  end
end
