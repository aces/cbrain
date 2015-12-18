class AddUrlToTools < ActiveRecord::Migration
  def change
    add_column :tools, :url, :string
  end
end
