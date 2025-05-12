
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

class DeleteAmazonScirData < ActiveRecord::Migration[5.0]
  def up
    # Delete all AmazonScir bourreaux, their associated tasks and tool configs
    # Any Amazon bourreau, tasks or configs will be lost irreversibly
    puts "Deleting AmazonScir bourreaux irreversibly... "
    amazon_bourreau_ids = Bourreau.where(cms_class: "ScirAmazon").pluck(:id)

    if amazon_bourreau_ids.empty?
      puts "No AmazonScir bourreaux found. No data to delete."
      return
    end

    puts "Found #{amazon_bourreau_ids.size} AmazonScir bourreaux. Deleting..."

    # Count records before deletion for logging purposes
    tasks_count        = CbrainTask.where(bourreau_id: amazon_bourreau_ids).count
    tool_configs_count = ToolConfig.where(bourreau_id: amazon_bourreau_ids).count

    # Delete associated records
    CbrainTask.where(bourreau_id: amazon_bourreau_ids).delete_all
    ToolConfig.where(bourreau_id: amazon_bourreau_ids).delete_all
    Bourreau.where(id: amazon_bourreau_ids).delete_all

    puts "Deleted #{tasks_count} tasks, #{tool_configs_count} tool configs, and #{amazon_bourreau_ids.size} bourreaux."
  end

  def down
    puts "This migration cannot be reversed as it permanently deletes data."
  end
end
