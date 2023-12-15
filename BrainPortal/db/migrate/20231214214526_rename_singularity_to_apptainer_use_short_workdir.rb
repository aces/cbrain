class RenameSingularityToApptainerUseShortWorkdir < ActiveRecord::Migration[5.0]
  def change
    rename_column :tool_configs, :singularity_use_short_workdir, :apptainer_use_short_workdir
  end
end
