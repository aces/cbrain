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
  end

  def self.down
    User.destroy_all
  end
end
