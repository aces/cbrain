
#
# CBRAIN Project
#
# Copyright (C) 2008-2019
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

class AddContainerizedPathToDataProvider < ActiveRecord::Migration[5.0]

  NewColumnName = :containerized_path

  def up
    add_column    :data_providers, NewColumnName, :string

    SingSquashfsDataProvider.all.to_a.each do |dp|
      dp.update_column(NewColumnName                   , dp.cloud_storage_client_path_start) # copy old info
      dp.update_column(:cloud_storage_client_path_start, nil                               ) # zap
    end

    true
  end

  def down
    SingSquashfsDataProvider.all.to_a.each do |dp|
      dp.update_column(:cloud_storage_client_path_start, dp.send(NewColumnName)            ) # restore to old place
    end

    remove_column :data_providers, NewColumnName

    true
  end

end
