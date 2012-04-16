
class AdjustMetaDataStoreArClass < ActiveRecord::Migration

  def self.up
    add_column    :meta_data_store, :ar_table_name, :string, :after => :ar_id
    add_index     :meta_data_store, [ :ar_id, :ar_table_name ]
    add_index     :meta_data_store, [ :ar_id, :ar_table_name, :meta_key ]
    add_index     :meta_data_store,         [ :ar_table_name, :meta_key ]

    MetaDataStore.reset_column_information
    MetaDataStore.reset_column_information_and_inheritable_attributes_for_all_subclasses rescue nil
    raise "Oh oh, can't find new column name in model?!?" unless MetaDataStore.columns_hash['ar_table_name'].present?

    puts "Adjusting #{MetaDataStore.count} meta data store entries (ar_class -> ar_table_name)... this may take some time."

    class_to_table = {}
    MetaDataStore.all.each_with_index do |md,idx|
      ar_table_name = (class_to_table[md.ar_class] ||= md.ar_class.constantize.table_name)
      md.update_attribute(:ar_table_name, ar_table_name)
      puts "  -> Updated #{idx+1} entries..." if idx % 50 == 49
    end

    remove_index  :meta_data_store,         [ :ar_class, :meta_key ]
    remove_index  :meta_data_store, [ :ar_id, :ar_class, :meta_key ]
    remove_index  :meta_data_store, [ :ar_id, :ar_class ]
    remove_column :meta_data_store, :ar_class
  end

  def self.down
    add_column    :meta_data_store, :ar_class, :string, :after => :ar_id
    add_index     :meta_data_store, [ :ar_id, :ar_class ]
    add_index     :meta_data_store, [ :ar_id, :ar_class, :meta_key ]
    add_index     :meta_data_store,         [ :ar_class, :meta_key ]

    MetaDataStore.reset_column_information
    MetaDataStore.reset_column_information_and_inheritable_attributes_for_all_subclasses rescue nil
    raise "Oh oh, can't find new column name in model?!?" unless MetaDataStore.columns_hash['ar_class'].present?

    puts "Adjusting #{MetaDataStore.count} meta data store entries (ar_table_name -> ar_class)... this may take some time."

    table_to_class = {}
    MetaDataStore.all.each_with_index do |md,idx|
      klass = (table_to_class[md.ar_table_name] ||= md.ar_table_name.classify.constantize)
      obj = klass.find(md.ar_id) rescue nil
      unless obj
        puts "To destroy ?!?: #{md.inspect}"
        #md.destroy
        next
      end
      md.update_attribute(:ar_class, obj.class.to_s)
      puts "  -> Updated #{idx+1} entries..." if idx % 50 == 49
    end

    remove_index  :meta_data_store,         [ :ar_table_name, :meta_key ]
    remove_index  :meta_data_store, [ :ar_id, :ar_table_name, :meta_key ]
    remove_index  :meta_data_store, [ :ar_id, :ar_table_name ]
    remove_column :meta_data_store, :ar_table_name
  end

end

