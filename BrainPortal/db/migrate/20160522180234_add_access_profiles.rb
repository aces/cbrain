
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

# Add a new model, AccessProfile, where we can
# store 'profiles' for new users. For the moments,
# profiles are just a bunch of groups.
#
# Preliminary, will expand later with quotas
# and maybe new types of access restrictions.
class AddAccessProfiles < ActiveRecord::Migration #:nodoc:
  def up
    create_table :access_profiles do |t|
      t.string :name,        :null => false
      t.string :description
      t.string :color

      t.timestamps
    end

    create_table :access_profiles_groups, :id => false do |t|
      t.integer :access_profile_id
      t.integer :group_id
    end
    create_table :access_profiles_users, :id => false do |t|
      t.integer :access_profile_id
      t.integer :user_id
    end
  end

  def self.down
    drop_table :access_profiles
    drop_table :access_profiles_groups
    drop_table :access_profiles_users
  end
end
