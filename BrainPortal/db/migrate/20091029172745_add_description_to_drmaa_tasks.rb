class AddDescriptionToDrmaaTasks < ActiveRecord::Migration
  def self.up
    add_column :drmaa_tasks, :description, :text
  end

  def self.down
    remove_column :drmaa_tasks, :description
  end
end
