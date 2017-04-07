class AddSingularityExecutableNameAndSingularityPresentToRemoteResources < ActiveRecord::Migration
  def change
    add_column :remote_resources, :singularity_executable_name, :string
    add_column :remote_resources, :singularity_present, :boolean
  end
end
