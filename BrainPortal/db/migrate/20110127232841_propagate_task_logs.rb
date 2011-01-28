class PropagateTaskLogs < ActiveRecord::Migration
  def self.up

    syszone = 'UTC'
    raise "No time zone configured for system?" unless syszone && ActiveSupport::TimeZone[syszone]
    if Time.zone.blank? || Time.zone.name != syszone
      Rails.configuration.time_zone = syszone
      Rails::Initializer.new(Rails.configuration).initialize_time_zone
    end

    CbrainTask.all.each do |task|
      oldlog = task.log
      next if oldlog.blank?
      task.raw_append_log(oldlog)
      task.log = nil
      task.save rescue true
    end

    remove_column :cbrain_tasks, :log

  end

  def self.down
    true
  end
end
