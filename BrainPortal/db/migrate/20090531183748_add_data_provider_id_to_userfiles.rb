class AddDataProviderIdToUserfiles < ActiveRecord::Migration
 def self.up
    add_column :userfiles, :data_provider_id, :integer
  end

  def self.down
    remove_column :userfiles, :data_provider_id
  end
end
