class RenameSingularityToApptainerExecutableName < ActiveRecord::Migration[5.0]
  def change
    rename_column :remote_resources, :singularity_executable_name, :apptainer_executable_name
  end
end
