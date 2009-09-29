class UnupgradeActiveRecordLogTable < ActiveRecord::Migration
  def self.up
    change_column :active_record_logs, :log, :text
  end

  def self.down
    change_column :active_record_logs, :log, :binary
  end
end
