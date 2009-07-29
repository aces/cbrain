class AdjustTasksForBourreauIds < ActiveRecord::Migration
  def self.up
    add_column    :drmaa_tasks, :bourreau_id, :integer
    remove_column :drmaa_tasks, :cluster_name

    # Transform to int
    remove_columns :user_preferences, :bourreau_id
    add_column     :user_preferences, :bourreau_id, :integer
  end

  def self.down
    add_column    :drmaa_tasks, :cluster_name, :string
    remove_column :drmaa_tasks, :bourreau_id

    # Transform to string
    remove_columns :user_preferences, :bourreau_id
    add_column     :user_preferences, :bourreau_id, :string
  end
end
