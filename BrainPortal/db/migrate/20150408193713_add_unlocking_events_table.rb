class AddUnlockingEventsTable < ActiveRecord::Migration
  def up
    create_table :ssh_agent_unlocking_events do |t|
      t.string :message
      t.timestamps
    end
  end

  def down
    drop_table :ssh_agent_unlocking_events
  end
end
