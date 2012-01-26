
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

class CreateCustomFilters < ActiveRecord::Migration
  def self.up
    create_table :custom_filters do |t|
      t.string    :name
      t.string    :file_name_type
      t.string    :file_name_term
      t.string    :created_date_type
      t.datetime  :created_date_term
      t.string    :size_type
      t.integer   :size_term
      t.integer   :group_id
      
      t.timestamps
    end
  end

  def self.down
    drop_table :custom_filters
  end
end

