
Object.send(:remove_const,:Tool) rescue true
class Tool < ActiveRecord::Base
end

class RenameToolsTasks < ActiveRecord::Migration
  def self.up
    Tool.all.each do |t|
      tc = t.drmaa_class
      t.drmaa_class = tc.sub(/^Drmaa/,"CbrainTask::")
      t.save!
    end
    rename_column :tools, :drmaa_class, :cbrain_task_class
  end

  def self.down
    Tool.all.each do |t|
      tc = t.cbrain_task_class
      t.cbrain_task_class = tc.sub(/^CbrainTask::/,"Drmaa")
      t.save!
    end
    rename_column :tools, :cbrain_task_class, :drmaa_class
  end
end
