class AdjustTasksForBourreauIds < ActiveRecord::Migration
  def self.up
    name2id = {}
    Bourreau.all.each { |b| name2id[b.name] = b.id }

    add_column    :drmaa_tasks, :bourreau_id, :integer

    # ActRecTask fetches the drmaa_task data as ActiveRecords...
    ActRecTask.all.each { |t| t.bourreau_id = name2id[t.cluster_name] ; t.save! }

    remove_column :drmaa_tasks, :cluster_name

    # Transform to int
    remove_columns :user_preferences, :bourreau_id
    add_column     :user_preferences, :bourreau_id, :integer
  end

  def self.down
    id2name = {}
    Bourreau.all.each { |b| id2name[b.id] = b.name }

    add_column    :drmaa_tasks, :cluster_name, :string

    # ActRecTask fetches the drmaa_task data as ActiveRecords...
    ActRecTask.all.each { |t| t.cluster_name = id2name[t.bourreau_id] ; t.save! }

    remove_column :drmaa_tasks, :bourreau_id

    # Transform to string
    remove_columns :user_preferences, :bourreau_id
    add_column     :user_preferences, :bourreau_id, :string
  end
end
