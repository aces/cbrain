
#
# CBRAIN Project
#
# Copyright (C) 2008-2022
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

# This migration makes DB adjustments specific to the
# CBRAIN plugin 'cbrain-plugins-neuro'. If the plugin is not
# installed or the plugin code's does not match what this
# migration requires, the migration will do nothing and
# will be trivially 'successful'.
#
# If later on the plugin is installed or upgraded such that it
# now DOES match the requirements, and the migration has already
# been trivially applied, then the migration can also be manually
# applied in the Rails console with the following Ruby commands:
#
#   load 'db/migrate/20220913183448_rename_recon_all.rb'
#   RenameReconAll.new.up  # or down to 'rollback'
class RenameReconAll < ActiveRecord::Migration[5.0]

  OLD_RECONALL_JSON = Pathname.new(Rails.root) + "cbrain_plugins/installed-plugins/cbrain_task_descriptors/freesurfer_7_1_1.json"

  def up
    return true if ! is_plugins_neuro_installed?
    return true if ! is_old_freesurfer_renamed?

    #------------------------------------------------------------------------
    puts "1- Attempting to find any spurious new Tool for FreeSurferReconAllBasic"
    badtool = Tool.where(:name => 'FreeSurfer_Recon_all_basic').first
    badtool = nil if badtool && badtool.tool_configs.count > 0
    if badtool
      puts " -> found, id=#{badtool.id}, removing it."
      badtool.destroy
    else
      puts " -> no found, all good."
    end

    #------------------------------------------------------------------------
    puts "2- Attempting to rename all CbrainTask::FreeSurferReconAll to CbrainTask::FreeSurferReconAllBasic"
    CbrainTask
      .where(      :type => 'CbrainTask::FreeSurferReconAll'      )
      .update_all( :type => 'CbrainTask::FreeSurferReconAllBasic' )

    #------------------------------------------------------------------------
    puts "3- Attempting to rename old tool class name"
    oldtool=Tool.where( :cbrain_task_class_name => 'CbrainTask::FreeSurferReconAll' ).first
    if oldtool
      puts " -> found, id=#{oldtool.id}, renaming name and cbrain_task_class_name"
      oldtool.update(
        :name                   => 'FreeSurfer_Recon_all_basic',
        :cbrain_task_class_name => 'CbrainTask::FreeSurferReconAllBasic',
      )
      oldtool.addlog "Migration renamed tool to FreeSurfer_Recon_all_basic and task class to CbrainTask::FreeSurferReconAllBasic"
    else
      puts " -> WARNING: tool not found. That's unusual, you might be updating your system in the wrong order"
    end

    #------------------------------------------------------------------------
    puts "4- Attempting to replicate all ToolConfigs of FreeSurfer_Recon_all_basic for FreeSurferReconAll"
    oldtool = Tool.where( :name => 'FreeSurfer_Recon_all_basic' ).first
    newtool = Tool.where( :name => 'FreeSurferReconAll'         ).first
    if (! oldtool || ! newtool)
      puts " -> Warning: new tool from Boutiques integrator is not present! Skipping."
    else
      oldtool.tool_configs.each do |tc|
        next if ToolConfig.where(:tool_id => newtool.id, :bourreau_id => tc.bourreau_id, :version_name => tc.version_name).exists?
        new_tc = tc.dup
        new_tc.tool_id = newtool.id
        puts " -> Adding new tool config as copy of TC ##{tc.id}"
        new_tc.save!
        new_tc.addlog("Created by migration as a copy of ToolConfig ##{tc.id}")
      end
    end

    true
  end

  def down
    return true if ! is_plugins_neuro_installed?
    return true if ! is_old_freesurfer_renamed?

    #------------------------------------------------------------------------
    puts "1- Attempting to revert all CbrainTask::FreeSurferReconAllBasic to CbrainTask::FreeSurferReconAll"
    CbrainTask
      .where(      :type => 'CbrainTask::FreeSurferReconAllBasic' )
      .update_all( :type => 'CbrainTask::FreeSurferReconAll'      )

    #------------------------------------------------------------------------
    puts "2- Attempting to revert tool class name"
    oldtool=Tool.where( :cbrain_task_class_name => 'CbrainTask::FreeSurferReconAllBasic' ).first
    if oldtool
      puts " -> found, id=#{oldtool.id}, renaming name and cbrain_task_class_name"
      oldtool.update(
        :cbrain_task_class_name => 'CbrainTask::FreeSurferReconAll',
        :name                   => 'FreeSurfer_Recon_all'
      )
      oldtool.addlog "Migration reverted task class to FreeSurferReconAll"
    else
      puts " -> WARNING: tool not found. That's unusual, you might be updating your system in the wrong order"
    end

    true
  end

  def is_plugins_neuro_installed?
    if ! File.file?(OLD_RECONALL_JSON)
      puts "This migration only applies for systems where the plugins 'cbrain-plugins-neuro' is installed."
      return false
    end
    true
  end

  def is_old_freesurfer_renamed?
    old_json = JSON.parse(File.read(OLD_RECONALL_JSON))
    if old_json['name'] != "FreeSurfer-Recon-all-basic"
      puts "This migration only applies for systems where, in 'cbrain-plugins-neuro', freesurfer.json has the new name 'FreeSurfer-Recon-all-basic'."
      return false
    end
    true
  end

end
