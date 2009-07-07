class CreateCustomFilters < ActiveRecord::Migration
  def self.up
    create_table :custom_filters do |t|
      t.string    :name
      t.string    :file_name_type
      t.string    :file_name_term
      t.string    :created_date_type
      t.datetime  :created_date_term
      t.string    :size_type
      t.integer   :size_term
      t.integer   :group_id
      
      t.timestamps
    end
  end

  def self.down
    drop_table :custom_filters
  end
end
