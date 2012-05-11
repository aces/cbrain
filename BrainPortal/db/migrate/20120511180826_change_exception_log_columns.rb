class ChangeExceptionLogColumns < ActiveRecord::Migration
  def self.up
    rename_column :exception_logs, :method, :request_method
    rename_column :exception_logs, :controller, :request_controller
    rename_column :exception_logs, :action, :request_action
    rename_column :exception_logs, :format, :request_format
    rename_column :exception_logs, :headers, :request_headers
  end

  def self.down
    rename_column :exception_logs, :request_method, :method
    rename_column :exception_logs, :request_controller, :controller
    rename_column :exception_logs, :request_action, :action
    rename_column :exception_logs, :request_format, :format
    rename_column :exception_logs, :request_headers, :headers
  end
end
