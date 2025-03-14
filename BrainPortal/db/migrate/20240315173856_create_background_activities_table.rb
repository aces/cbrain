class CreateBackgroundActivitiesTable < ActiveRecord::Migration[5.0]
  def change
    create_table :background_activities do |t|

      # Type indicate what type of action
      t.string  :type, :null => false      # for single table inheritance

      # Owner of the activity's requester
      t.integer :user_id,            :optional => false

      # Which application within CBRAIN is supposed to handle this BA
      t.integer :remote_resource_id, :optional => false

      # Status of the background activity
      t.string  :status, :null => false
      t.string  :handler_lock

      # The main list of items to process (array of arbitrary things)
      t.text    :items,         :null => false
      # Counters and messages for these items
      t.integer :current_item,  :default => 0
      t.integer :num_successes, :default => 0
      t.integer :num_failures,  :default => 0
      t.text    :messages  # array of error or success messages

      # Other params specific to the activity type
      t.text    :options

      # Timestamps
      t.timestamps

      # Scheduling attributes
      t.datetime :start_at
      t.string   :repeat

    end
  end
end
