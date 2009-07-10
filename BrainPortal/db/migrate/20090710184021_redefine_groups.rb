class RedefineGroups < ActiveRecord::Migration
  def self.up
    remove_column :groups,  :institution_id
    remove_column :groups,  :manager_id
    remove_column :groups,  :street
    remove_column :groups,  :building
    remove_column :groups,  :room
    remove_column :groups,  :phone
    remove_column :groups,  :fax
    
    remove_column :institutions,  :group_id
  end

  def self.down
    add_column :groups,  :institution_id, :integer
    add_column :groups,  :manager_id    , :integer
    add_column :groups,  :street        , :string 
    add_column :groups,  :building      , :string 
    add_column :groups,  :room          , :string 
    add_column :groups,  :phone         , :string 
    add_column :groups,  :fax           , :string 
    
    add_column :institutions,  :group_id, :integer 
  end                                   
end
