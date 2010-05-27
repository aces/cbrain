class RenameStatisticsTasks < ActiveRecord::Migration
  def self.up
    Statistic.all.each do |s|
      tname = s.task_name
      s.task_name = tname.sub(/^Drmaa/,"CbrainTask::")
      s.save!
    end
  end

  def self.down
    Statistic.all.each do |s|
      tname = s.task_name
      s.task_name = tname.sub(/^CbrainTask::/,"Drmaa")
      s.save!
    end
  end
end
