class CreateActiveRecordLogTable < ActiveRecord::Migration

  def self.up
    create_table :active_record_logs do |t|

      t.integer  :ar_id
      t.string   :ar_class
      t.text     :log

      t.timestamps
    end
    add_index    :active_record_logs, [ :ar_id, :ar_class ]
  end

  def self.down
    remove_index :active_record_logs, [ :ar_id, :ar_class ]
    drop_table   :active_record_logs
  end

end
