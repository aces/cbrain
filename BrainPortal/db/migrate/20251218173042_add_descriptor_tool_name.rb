class AddDescriptorToolName < ActiveRecord::Migration[5.0]
  def change
    add_column :tools, :descriptor_name, :string, :after => :name
  end
end
