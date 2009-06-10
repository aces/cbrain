class CreateDataProviders < ActiveRecord::Migration
  def self.up
    create_table :data_providers do |t|
      t.string  :name
      t.string  :type          # for polymorphism
      t.integer :user_id
      t.integer :group_id

      t.string  :remote_user
      t.string  :remote_host
      t.integer :remote_port
      t.string  :remote_dir

      t.boolean :online
      t.boolean :read_only

      t.string  :description

      t.timestamps
    end
  end

  def self.down
    drop_table :data_providers
  end
end
