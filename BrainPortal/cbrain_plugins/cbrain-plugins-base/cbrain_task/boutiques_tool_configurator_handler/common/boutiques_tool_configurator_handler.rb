
#
# CBRAIN Project
#
# Copyright (C) 2022
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

# Common methods for both sides, Portal and Bourreau

class BoutiquesToolConfiguratorHandler

  def selected_old_tool_config
    @_old_tc ||= selected_tool_config(self.invoke_params[:old_tool_config_id])
  end

  def selected_new_tool_config
    @_new_tc ||= selected_tool_config(self.invoke_params[:new_tool_config_id])
  end

  def selected_tool_config(tool_config_id)
    return nil if tool_config_id.blank?
    return nil unless tool_config_id.to_s.match /\A(\d+)\z/
    tc_id = Regexp.last_match[1]
    ToolConfig.where(:id => tc_id).first
  end

  # Transforms e.g. docker://org/prog:1.2 into "org_prog_1_2.sif"
  def docker_name_to_sif_name(docker_name)
    docker_name
      .sub(/^(docker:)?(\/*)/,"")
      .gsub(/\W+/,"_")
      .sub(/^_+/,"")
      .sub(/_+$/,"") + ".sif"
  end

  # NOTE: Modifies the desc !
  def fix_value_choices_for_tool_configs(desc) #:nodoc:
    old_tc = selected_old_tool_config
    new_tc = selected_new_tool_config
    if old_tc
      desc.input_by_id('old_tool_config_id').value_choices = [ self.invoke_params[:old_tool_config_id].to_s ]
    end
    if new_tc
      desc.input_by_id('new_tool_config_id').value_choices = [ self.invoke_params[:new_tool_config_id].to_s ]
    end
  end

end

