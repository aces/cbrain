
class AdjustActRecLogArClass < ActiveRecord::Migration

  def self.up
    add_column    :active_record_logs, :ar_table_name, :string, :after => :ar_id
    add_index     :active_record_logs, [ :ar_id, :ar_table_name ]

    ActiveRecordLog.reset_column_information
    ActiveRecordLog.reset_column_information_and_inheritable_attributes_for_all_subclasses rescue nil
    raise "Oh oh, can't find new column name in model?!?" unless ActiveRecordLog.columns_hash['ar_table_name'].present?

    puts "Adjusting #{ActiveRecordLog.count} log entries (ar_class -> ar_table_name)... this may take some time."

    class_to_table = {}
    ActiveRecordLog.all.each_with_index do |arl,idx|
      ar_table_name = (class_to_table[arl.ar_class] ||= arl.ar_class.constantize.table_name)
      arl.update_attribute(:ar_table_name, ar_table_name)
      puts "  -> Updated #{idx+1} entries..." if idx % 50 == 49
    end

    remove_index  :active_record_logs, [ :ar_id, :ar_class ]
    remove_column :active_record_logs, :ar_class
  end

  def self.down
    add_column    :active_record_logs, :ar_class, :string, :after => :ar_id
    add_index     :active_record_logs, [ :ar_id, :ar_class ]

    ActiveRecordLog.reset_column_information
    ActiveRecordLog.reset_column_information_and_inheritable_attributes_for_all_subclasses rescue nil
    raise "Oh oh, can't find new column name in model?!?" unless ActiveRecordLog.columns_hash['ar_class'].present?

    puts "Adjusting #{ActiveRecordLog.count} log entries (ar_table_name -> ar_class)... this may take some time."

    table_to_class = {}
    ActiveRecordLog.all.each_with_index do |arl,idx|
      klass = (table_to_class[arl.ar_table_name] ||= arl.ar_table_name.classify.constantize)
      obj = klass.find(arl.ar_id) rescue nil
      unless obj
        #puts "To destroy ?!?: #{arl.inspect}"
        arl.destroy
        next
      end
      arl.update_attribute(:ar_class, obj.class.to_s)
      puts "  -> Updated #{idx+1} entries..." if idx % 50 == 49
    end

    remove_index  :active_record_logs, [ :ar_id, :ar_table_name ]
    remove_column :active_record_logs, :ar_table_name
  end

end

