class RenameSingularityToApprainer < ActiveRecord::Migration[5.0]
  def change
    rename_column :tool_configs, :singularity_overlays_specs, :apptainer_overlays_specs
    rename_column :tool_configs, :singularity_use_short_workdir, :apptainer_use_short_workdir
    rename_column :remote_resources, :singularity_executable_name, :apptainer_executable_name
  end
end
