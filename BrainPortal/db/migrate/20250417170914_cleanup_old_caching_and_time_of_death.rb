
#
# CBRAIN Project
#
# Copyright (C) 2008-2025
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
# along with this program. If not, see https://www.gnu.org/licenses
#

class CleanupOldCachingAndTimeOfDeath < ActiveRecord::Migration[5.0]

  def up
    remove_column :remote_resources, :time_of_death
    RemoteResource.all.each do |rr|
      rr.meta[:ping_cache]             = nil
      rr.meta[:info_cache]             = nil
      rr.meta[:ping_cache_last_update] = nil
      rr.meta[:info_cache_last_update] = nil
    end
  end

  def down
    add_column :remote_resources, :time_of_death, :datetime
  end

end
