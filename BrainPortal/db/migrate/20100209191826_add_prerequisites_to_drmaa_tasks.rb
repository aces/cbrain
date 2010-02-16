class AddPrerequisitesToDrmaaTasks < ActiveRecord::Migration
  def self.up
    add_column :drmaa_tasks, :prerequisites,  :text
    add_column :drmaa_tasks, :share_wd_tid,   :integer
    add_column :drmaa_tasks, :run_number,     :integer
  end

  def self.down
    remove_column :drmaa_tasks, :prerequisites
    remove_column :drmaa_tasks, :share_wd_tid
    remove_column :drmaa_tasks, :run_number
  end
end
