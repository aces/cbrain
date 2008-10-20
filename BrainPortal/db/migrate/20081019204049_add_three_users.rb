class AddThreeUsers < ActiveRecord::Migration
  def self.up
    User.create(
      :user_name       => "admin",
      :crypt_password  => "cbjD3g4xCNCUc",
      :full_name       => "CBRAIN Admin"
    )
    User.create(
      :user_name       => "prioux",
      :crypt_password  => "cbjD3g4xCNCUc",
      :full_name       => "Pierre Rioux"
    )
    User.create(
      :user_name       => "tsherif",
      :crypt_password  => "cbjD3g4xCNCUc",
      :full_name       => "Tarek Sherif"
    )
    User.create(
      :user_name       => "mero",
      :crypt_password  => "cbjD3g4xCNCUc",
      :full_name       => "Marc-Etienne Rousseau"
    )
  end

  def self.down
    User.delete_all
  end

end
