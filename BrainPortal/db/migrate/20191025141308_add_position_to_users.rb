class AddPositionToUsers < ActiveRecord::Migration[5.0]

  def up
    add_column :users, :position, :string, :after => :full_name

    User.all.each do |user|
      user.position = extract_position_from_log(user.getlog || "") || "Unknown"
      user.save
    end
  end

  def extract_position_from_log(log)
    log[/Position:\s*(.+?)\s*$/m, 1]
  end

  def down
    remove_column :users, :position, :string
  end

end
