class AddDockerExecutableNameToRemoteResources < ActiveRecord::Migration
  def change
    add_column :remote_resources, :docker_executable_name, :string
  end
end
