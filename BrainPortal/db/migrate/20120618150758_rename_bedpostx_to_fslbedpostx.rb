class CbrainTask::Bedpostx < ActiveRecord::Base
   self.table_name = "cbrain_tasks"
end

class RenameBedpostxToFslbedpostx < ActiveRecord::Migration
  
  def self.up
    CbrainTask.where(:type => "CbrainTask::Bedpostx").update_all(:type => "CbrainTask::FslBedpostx")
  end

  def self.down
    CbrainTask.where(:type => "CbrainTask::FslBedpostx").update_all(:type => "CbrainTask::Bedpostx")
  end
end
