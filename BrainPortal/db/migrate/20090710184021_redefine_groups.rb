
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

class RedefineGroups < ActiveRecord::Migration
  def self.up
    remove_column :groups,  :institution_id
    remove_column :groups,  :manager_id
    remove_column :groups,  :street
    remove_column :groups,  :building
    remove_column :groups,  :room
    remove_column :groups,  :phone
    remove_column :groups,  :fax
    
    remove_column :institutions,  :group_id
  end

  def self.down
    add_column :groups,  :institution_id, :integer
    add_column :groups,  :manager_id    , :integer
    add_column :groups,  :street        , :string 
    add_column :groups,  :building      , :string 
    add_column :groups,  :room          , :string 
    add_column :groups,  :phone         , :string 
    add_column :groups,  :fax           , :string 
    
    add_column :institutions,  :group_id, :integer 
  end                                   
end

