class RawGroup < ActiveRecord::Base
   self.table_name = "groups"
end

class InvisibleGroup < RawGroup
end

class AddInvisibleToGroups < ActiveRecord::Migration
  def self.up
    add_column :groups, :invisible, :boolean, :default => false
    add_index  :groups, :invisible
    
    RawGroup.reset_column_information
    
    RawGroup.where(type: "InvisibleGroup").all.each do |g|
      g.invisible = true
      g.type = "WorkGroup"
      g.save!
    end
    
  end

  def self.down
    
    RawGroup.where(invisible: true).all.each do |g|
      g.type = "InvisibleGroup"
      g.save!
    end
    
    remove_column :groups, :invisible
  end
end
