
#
# CBRAIN Project
#
# Copyright (C) 2008-2012
# The Royal Institution for the Advancement of Learning
# McGill University
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.  
#

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

