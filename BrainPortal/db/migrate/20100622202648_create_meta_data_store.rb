class CreateMetaDataStore < ActiveRecord::Migration

  def self.up
    create_table :meta_data_store do |t|

      t.integer  :ar_id
      t.string   :ar_class
      t.string   :meta_key
      t.text     :meta_value

      t.timestamps
    end
    add_index    :meta_data_store,                    [ :meta_key ]
    add_index    :meta_data_store, [ :ar_id, :ar_class ]
    add_index    :meta_data_store, [ :ar_id, :ar_class, :meta_key ]
    add_index    :meta_data_store,         [ :ar_class, :meta_key ]
  end

  def self.down
    remove_index :meta_data_store,         [ :ar_class, :meta_key ]
    remove_index :meta_data_store, [ :ar_id, :ar_class, :meta_key ]
    remove_index :meta_data_store, [ :ar_id, :ar_class ]
    remove_index :meta_data_store,                    [ :meta_key ]
    drop_table   :meta_data_store
  end

end
