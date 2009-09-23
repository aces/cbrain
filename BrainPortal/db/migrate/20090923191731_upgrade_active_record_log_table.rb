class UpgradeActiveRecordLogTable < ActiveRecord::Migration
  def self.up
    change_column :active_record_logs, :log, :binary
  end

  def self.down
    change_column :active_record_logs, :log, :text
  end
end
