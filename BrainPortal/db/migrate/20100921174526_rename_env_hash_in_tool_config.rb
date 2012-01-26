
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

class RenameEnvHashInToolConfig < ActiveRecord::Migration
  def self.up
    rename_column :tool_configs, :env_hash,  :env_array
    ToolConfig.all.each do |tc|
      myenv = tc.env_array
      next if myenv.nil? || myenv.is_a?(Array)
      newenv = myenv.keys.collect { |name| [ name, myenv[name] ] }
      tc.env_array = newenv
      tc.save
    end
  end

  def self.down
    rename_column :tool_configs, :env_array, :env_hash
    ToolConfig.all.each do |tc|
      myenv = tc.env_hash
      next if myenv.nil? || myenv.is_a?(Hash)
      newenv = {}
      myenv.each do |name_val|
        name = name_val[0]
        val  = name_val[1]
        newenv[name] = val
      end
      tc.env_hash = newenv
      tc.save
    end
  end
end

