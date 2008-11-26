class CreateDrmaaTasks < ActiveRecord::Migration
  def self.up
    create_table :drmaa_tasks do |t|
      t.string   :type
      t.string   :drmaa_jobid
      t.string   :drmaa_workdir
      t.text     :params
      t.string   :status
      t.text     :log
      t.timestamps
    end
  end

  def self.down
    drop_table :drmaa_tasks
  end
end
