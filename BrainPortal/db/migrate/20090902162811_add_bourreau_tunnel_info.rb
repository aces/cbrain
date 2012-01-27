
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

class AddBourreauTunnelInfo < ActiveRecord::Migration
  def self.up
    rename_column :remote_resources, :remote_user,           :actres_user
    rename_column :remote_resources, :remote_host,           :actres_host
    rename_column :remote_resources, :remote_port,           :actres_port
    rename_column :remote_resources, :remote_dir,            :actres_dir

    add_column    :remote_resources, :ssh_control_user,      :string
    add_column    :remote_resources, :ssh_control_host,      :string
    add_column    :remote_resources, :ssh_control_port,      :integer

    add_column    :remote_resources, :ssh_control_rails_dir, :string

    add_column    :remote_resources, :tunnel_mysql_port,     :integer
    add_column    :remote_resources, :tunnel_actres_port,    :integer
  end

  def self.down
    rename_column :remote_resources, :actres_host,           :remote_host
    rename_column :remote_resources, :actres_port,           :remote_port
    rename_column :remote_resources, :actres_user,           :remote_user
    rename_column :remote_resources, :actres_dir,            :remote_dir

    remove_column :remote_resources, :ssh_control_user
    remove_column :remote_resources, :ssh_control_host
    remove_column :remote_resources, :ssh_control_port

    remove_column :remote_resources, :ssh_control_rails_dir

    remove_column :remote_resources, :tunnel_mysql_port
    remove_column :remote_resources, :tunnel_actres_port
  end
end

