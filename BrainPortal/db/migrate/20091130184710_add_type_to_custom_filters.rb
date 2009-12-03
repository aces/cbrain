class AddTypeToCustomFilters < ActiveRecord::Migration
  def self.up
    add_column :custom_filters, :type, :string
  end

  def self.down
    remove_column :custom_filters, :type
  end
end
