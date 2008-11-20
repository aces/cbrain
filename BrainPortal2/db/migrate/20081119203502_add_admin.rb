class AddAdmin < ActiveRecord::Migration
  def self.up
    User.create(
      :full_name       => "Admin",
      :login           => "admin",
      :password  => 'admin',
      :password_confirmation => 'admin',
      :email => 'admin@here',
      :role => 'admin'
    )
    
    admindir = Pathname.new(CBRAIN::Filevault_dir) + 'admin'
    Dir.mkdir(admindir.to_s) unless File.directory?(admindir.to_s)
  end

  def self.down
    User.destroy_all
    admindir = Pathname.new(CBRAIN::Filevault_dir) + 'admin'
    Dir.rmdir(admindir.to_s) if File.directory?(admindir.to_s)
  end
end
