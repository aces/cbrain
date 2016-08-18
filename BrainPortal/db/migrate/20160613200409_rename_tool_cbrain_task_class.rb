class RenameToolCbrainTaskClass < ActiveRecord::Migration
  def change
    rename_column :tools, :cbrain_task_class,      :cbrain_task_class_name
  end
end
