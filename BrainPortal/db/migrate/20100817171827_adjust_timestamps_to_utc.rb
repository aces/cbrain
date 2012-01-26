
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

class AdjustTimestampsToUtc < ActiveRecord::Migration

  def self.up

    self.verify_timezone_configured

    offset = self.get_offset

    puts <<-"INFO"

  If this is correct, enter the keyword 'yes' and we will adjust all the
  old timestamps in the database (which were using the local time) to
  convert them to UTC time. If this doesn't seem right, hit CTRL-C or
  enter "NO" now.

    INFO

    print "Proceed (yes/no) ? "
    answer = STDIN.readline

    if answer !~ /^\s*yes\s*$/i
      raise "Timestamp adjustment migration aborted by user."
    end

    self.apply_offset(0-offset) # offsets are added, so we switch the sign
  end

  def self.down

    self.verify_timezone_configured

    offset = self.get_offset

    puts <<-"INFO"

  If this is correct, enter the keyword 'yes' and we will adjust all the
  timestamps in the database (which were using UTC time) to convert
  them back to local time. If this doesn't seem right, hit CTRL-C or
  enter "NO" now.

    INFO

    print "Proceed (yes/no) ? "
    answer = STDIN.readline

    if answer !~ /^\s*yes\s*$/i
      raise "Timestamp adjustment migration aborted by user."
    end

    self.apply_offset(offset) # offsets are added, so we simply apply it to revert
  end

  def self.verify_timezone_configured

    return if ! Time.zone.blank?

    print <<-"TZ_ERROR"

  Error: Configuration incomplete!

  For this migration to work, you must make sure that the
  Rails application has the proper time zone configured
  in this file:

     #{Rails.root.to_s}/config/environment.rb

  Edit the file and change this line so it says:

     config.time_zone = "your time zone name"

  The full list of time zone names can be obtained by
  running the rake task:

    rake time:zones:all

  and a more particular subset of acceptable names
  for your current machine can be seen by running

    rake time:zones:local

    TZ_ERROR

    raise "Configuration Incomplete"
  end

  def self.get_offset

    offset = Time.zone.now.utc_offset

    puts <<-"INFO"

  It seems the time difference between the local time zone,

    #{Time.now.zone}

  and Universal Time is #{offset} seconds (#{offset / 3600} hours).

  These numbers should be negative if you are in the western hemisphere,
  and positive in the Eastern one.

    INFO

    offset
  end

  def self.apply_offset(offset)

    models = ActiveRecord::Base.descendants.select { |c| c.superclass == ActiveRecord::Base }
    models.each do |model|

      next if model.name == "ActiveRecord::SessionStore::Session"

      puts "\n"
      puts "============================================"
      puts "Adjusting timestamps for model #{model.name}"
      puts "============================================"
      puts "\n"

      begin

      columns = model.columns
      cols_to_adjust = []
      columns.each do |col|
        next if col.type != :datetime
        puts "\t-> Found datetime attribute:\t#{col.name}"
        cols_to_adjust << col
      end

      if cols_to_adjust.size == 0
        puts "\t-> No datetime columns to adjust, skipping this model."
        next
      end

      puts "\n"
      puts "Scanning objects for model #{model.name}"
      objects = model.all
      puts "\t-> #{objects.size} objects to adjust...\n"

      cnt = 0

      objects.each do |obj|
        cnt += 1
        cols_to_adjust.each do |col|
          orig = obj.send(col.name)
          next unless orig.is_a?(Time)
          new = orig + offset.seconds
          obj.send("#{col.name}=",new)
          #puts "\t-> #{col.name} : #{orig} -> #{new}"
          obj.instance_eval { def self.write_attribute(a,b);end } # disable further mods to attributes, so updated_at stays AS IS
        end
        obj.save!
        puts "\t\t-> Updated #{cnt} objects..." if cnt % 100 == 0
      end

      puts "\t-> Finished updating #{cnt} objects..."

      rescue

        puts "\t-> Error. Maybe the table doesn't exist. Never mind. Skipped."

      end

    end

    true
  end

end

