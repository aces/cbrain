
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

