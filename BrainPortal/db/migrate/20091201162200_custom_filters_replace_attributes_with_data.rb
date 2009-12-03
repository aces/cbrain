class CustomFiltersReplaceAttributesWithData < ActiveRecord::Migration
  def self.up
    remove_column :custom_filters,  :file_name_type
    remove_column :custom_filters,  :file_name_term
    remove_column :custom_filters,  :created_date_type
    remove_column :custom_filters,  :created_date_term
    remove_column :custom_filters,  :size_type
    remove_column :custom_filters,  :size_term
    remove_column :custom_filters,  :group_id
    remove_column :custom_filters,  :tags
    
    add_column    :custom_filters,  :data, :text
  end

  def self.down
    add_column    :custom_filters, :file_name_type   , :string   
    add_column    :custom_filters, :file_name_term   , :string   
    add_column    :custom_filters, :created_date_type, :string   
    add_column    :custom_filters, :created_date_term, :datetime 
    add_column    :custom_filters, :size_type        , :string   
    add_column    :custom_filters, :size_term        , :integer  
    add_column    :custom_filters, :group_id         , :integer  
    add_column    :custom_filters, :tags             , :text     
    
    remove_column :custom_filters, :data
  end
end
