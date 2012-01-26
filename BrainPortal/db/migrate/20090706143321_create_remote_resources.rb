
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

class CreateRemoteResources < ActiveRecord::Migration
  def self.up
    create_table :remote_resources do |t|
      t.string  :name
      t.string  :type          # for polymorphism
      t.integer :user_id
      t.integer :group_id

      t.string  :remote_user
      t.string  :remote_host
      t.integer :remote_port
      t.string  :remote_dir

      t.boolean :online
      t.boolean :read_only

      t.string  :description

      t.timestamps
    end
  end

  def self.down
    drop_table :remote_resources
  end
end

