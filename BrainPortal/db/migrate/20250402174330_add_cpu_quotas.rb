
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
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

class AddCpuQuotas < ActiveRecord::Migration[5.0]

  def change
    rename_table :disk_quotas, :quotas

    add_column   :quotas, :type,               :string,  :after => :id
    add_column   :quotas, :group_id,           :integer, :after => :user_id
    add_column   :quotas, :remote_resource_id, :integer, :after => :max_files
    add_column   :quotas, :max_cpu_past_week,  :integer, :after => :remote_resource_id
    add_column   :quotas, :max_cpu_past_month, :integer, :after => :max_cpu_past_week
    add_column   :quotas, :max_cpu_ever,       :integer, :after => :max_cpu_past_month
  end

end
