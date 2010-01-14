class AddSelectMenuTextAndDescriptionToTools < ActiveRecord::Migration
  def self.up
    add_column :tools, :select_menu_text, :string
    add_column :tools, :description, :text
  end

  def self.down
    remove_column :tools, :description
    remove_column :tools, :select_menu_text
  end
end
