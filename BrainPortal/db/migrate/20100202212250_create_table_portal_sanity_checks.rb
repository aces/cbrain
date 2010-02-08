class CreateTablePortalSanityChecks < ActiveRecord::Migration
  def self.up
    create_table :sanity_checks do |t|
      t.string :revision_info
      t.timestamps
    end
  end

  def self.down
    drop_table :sanity_checks
  end
end
