class AddCleanupPoliciesToCbrainTasks < ActiveRecord::Migration[5.0]
  def change
    add_column :cbrain_tasks, :success_cleanup_policy, :string, default: 'keep_all'
    add_column :cbrain_tasks, :failure_cleanup_policy, :string, default: 'keep_all'
  end
end