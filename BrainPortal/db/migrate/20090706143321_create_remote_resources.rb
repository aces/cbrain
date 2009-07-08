class CreateRemoteResources < ActiveRecord::Migration
  def self.up
    create_table :remote_resources do |t|
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
    drop_table :remote_resources
  end
end
