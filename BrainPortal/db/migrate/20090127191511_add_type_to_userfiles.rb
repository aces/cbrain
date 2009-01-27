class AddTypeToUserfiles < ActiveRecord::Migration
  def self.up
    add_column :userfiles, :type, :string
    
    Userfile.all.each do |userfile|
      userfile.type  = 'SingleFile'
      userfile.save
    end
  end

  def self.down
    remove_column :userfiles, :type
  end
end
