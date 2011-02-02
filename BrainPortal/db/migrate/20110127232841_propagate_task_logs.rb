class PropagateTaskLogs < ActiveRecord::Migration
  def self.up

    syszone = 'UTC'
    raise "No time zone configured for system?" unless syszone && ActiveSupport::TimeZone[syszone]
    if Time.zone.blank? || Time.zone.name != syszone
      Rails.configuration.time_zone = syszone
      Rails::Initializer.new(Rails.configuration).initialize_time_zone
    end

    tot = CbrainTask.count
    puts "Upgrading #{tot} task objects."
    CbrainTask.all.each_with_index do |task,i|
      oldlog = task.log rescue ""   # old API has .log(), new API has .getlog()
      next if oldlog.blank?
      task.raw_append_log(oldlog)
      task.log = nil
      task.save rescue true
      puts "... upgraded #{i} task objects out of #{tot}" if (i+1) % 50 == 0
    end
    puts "Finished upgrading #{tot} task objects."

    remove_column :cbrain_tasks, :log

  end

  def self.down
    add_column    :cbrain_tasks, :log, :text
  end
end
