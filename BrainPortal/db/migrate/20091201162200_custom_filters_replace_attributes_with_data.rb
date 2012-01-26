
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

class CustomFiltersReplaceAttributesWithData < ActiveRecord::Migration
  def self.up
    remove_column :custom_filters,  :file_name_type
    remove_column :custom_filters,  :file_name_term
    remove_column :custom_filters,  :created_date_type
    remove_column :custom_filters,  :created_date_term
    remove_column :custom_filters,  :size_type
    remove_column :custom_filters,  :size_term
    remove_column :custom_filters,  :group_id
    remove_column :custom_filters,  :tags
    
    add_column    :custom_filters,  :data, :text
  end

  def self.down
    add_column    :custom_filters, :file_name_type   , :string   
    add_column    :custom_filters, :file_name_term   , :string   
    add_column    :custom_filters, :created_date_type, :string   
    add_column    :custom_filters, :created_date_term, :datetime 
    add_column    :custom_filters, :size_type        , :string   
    add_column    :custom_filters, :size_term        , :integer  
    add_column    :custom_filters, :group_id         , :integer  
    add_column    :custom_filters, :tags             , :text     
    
    remove_column :custom_filters, :data
  end
end

