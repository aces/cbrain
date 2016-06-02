class AddCloudJobSlotsToToolConfig < ActiveRecord::Migration
  def change
    add_column :tool_configs, :cloud_job_slots, :int
  end
end
