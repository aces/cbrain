class RenameSingularityToApptainerOverlaysSpecs < ActiveRecord::Migration[5.0]
  def change
    rename_column :tool_configs, :singularity_overlays_specs, :apptainer_overlays_specs
  end
end
