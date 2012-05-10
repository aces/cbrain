class CreateExceptionLogs < ActiveRecord::Migration
  def self.up
    create_table :exception_logs do |t|
      t.string :exception_class
      t.string :controller
      t.string :action
      t.string :method
      t.string :format
      t.integer :user_id
      t.text :message
      t.text :backtrace
      t.text :request
      t.text :session
      t.text :headers
      t.string :instance_name
      t.string :revision_no

      t.timestamps
    end
  end

  def self.down
    drop_table :exception_logs
  end
end
