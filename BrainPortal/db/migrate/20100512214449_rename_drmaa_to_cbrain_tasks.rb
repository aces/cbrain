
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

Object.send(:remove_const,:DrmaaTask) rescue true
Object.send(:remove_const,:CbrainTask) rescue true
class RawTask < ActiveRecord::Base
   self.table_name = "cbrain_tasks"
   serialize :prerequisites
   serialize :params
end
class CbrainTask < RawTask
end
class DrmaaTask < RawTask
end

sci_names = []
Dir.entries("#{Rails.root.to_s}/app/models").each do |e|
  next unless e =~ /\.rb$/ && e =~ /^drmaa_/ && e !~ /drmaa_task/
  e.sub!(/\.rb$/,"")
  e.sub!(/^drmaa_/,"")
  e = e.camelize
  sci_names |= [ e ]
end

Dir.entries("#{Rails.root.to_s}/app/models/cbrain_task").each do |e|
  next unless e =~ /\.rb$/ && e !~ /web_interface/
  e.sub!(/\.rb$/,"")
  e = e.camelize
  sci_names |= [ e ]
end

sci_names.each do |e|
  puts "Preparing fake ActiveRecord classes for '#{e}'..."
  eval "Object.send(:remove_const,:Drmaa#{e})" rescue true
  eval "CbrainTask.send(:remove_const,:#{e})"  rescue true
  eval "class Drmaa#{e}        < RawTask;end"
  eval "class CbrainTask::#{e} < RawTask;end"
end

class RenameDrmaaToCbrainTasks < ActiveRecord::Migration

  def self.up
    RawTask.all.each do |t|
      oldtype = t.type.to_s
      newtype = oldtype.sub(/^Drmaa/,"CbrainTask::")
      t.type  = newtype
      puts "Adjusting #{oldtype} #{t.id} to #{newtype}..."
      t.save!
    end
  end

  def self.down
    RawTask.all.each do |t|
      newtype = t.type.to_s
      oldtype = newtype.sub(/^CbrainTask::/,"Drmaa")
      t.type  = oldtype
      puts "Adjusting #{newtype} #{t.id} to #{oldtype}..."
      t.save!
    end
  end

end

