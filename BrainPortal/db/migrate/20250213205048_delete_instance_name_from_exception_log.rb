class DeleteInstanceNameFromExceptionLog < ActiveRecord::Migration[5.0]
  def change
    remove_column :exception_logs, :instance_name, :string
  end
end
