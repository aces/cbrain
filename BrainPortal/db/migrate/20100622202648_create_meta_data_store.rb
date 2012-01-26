
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

class CreateMetaDataStore < ActiveRecord::Migration

  def self.up
    create_table :meta_data_store do |t|

      t.integer  :ar_id
      t.string   :ar_class
      t.string   :meta_key
      t.text     :meta_value

      t.timestamps
    end
    add_index    :meta_data_store,                    [ :meta_key ]
    add_index    :meta_data_store, [ :ar_id, :ar_class ]
    add_index    :meta_data_store, [ :ar_id, :ar_class, :meta_key ]
    add_index    :meta_data_store,         [ :ar_class, :meta_key ]
  end

  def self.down
    remove_index :meta_data_store,         [ :ar_class, :meta_key ]
    remove_index :meta_data_store, [ :ar_id, :ar_class, :meta_key ]
    remove_index :meta_data_store, [ :ar_id, :ar_class ]
    remove_index :meta_data_store,                    [ :meta_key ]
    drop_table   :meta_data_store
  end

end

