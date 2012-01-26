
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

class AddExceptionTable < ActiveRecord::Migration
  def self.up
    create_table "logged_exceptions", :force => true do |t|
      t.column :exception_class, :string
      t.column :controller_name, :string
      t.column :action_name,     :string
      t.column :message,         :text
      t.column :backtrace,       :text
      t.column :environment,     :text
      t.column :request,         :text
      t.column :created_at,      :datetime
    end
  end

  def self.down
    drop_table "logged_exceptions"
  end
end

