
#
# CBRAIN Project
#
# Copyright (C) 2024
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

# This class is an intermediate class between BoutiquesPortalTask and
# BoutiquesToolConfigurator. It provides special functionality
# to allow the interface to dynamically show the list of ToolConfigs.
class BoutiquesToolConfiguratorHandler < BoutiquesClusterTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def descriptor_for_cluster_commands
    desc = super.dup
    fix_value_choices_for_tool_configs(desc)
    desc
  end

  def save_results
    return false unless super

    id_of_sif = self.params[:_cbrain_output_apptainer_sif_name].last
    siffile   = ApptainerImage.find(id_of_sif)
    new_tc    = selected_new_tool_config

    self.addlog "Configuring NEW ToolConfig #{new_tc.bourreau.name}/#{new_tc.tool.name} #{new_tc.version_name} (ID ##{new_tc.id})"

    new_tc.container_image_userfile_id = siffile.id
    new_tc.containerhub_image_name     = nil
    new_tc.container_engine            = "Singularity"
    new_tc.container_index_location    = nil

    new_tc.save_with_logging(self.user,
      %i(
        container_image_userfile_id
        containerhub_image_name
        container_engine
        container_index_location
      )
    )

    self.addlog "ToolConfig SIF Image: #{siffile.name} (ID ##{id_of_sif})"
    true
  end

end

