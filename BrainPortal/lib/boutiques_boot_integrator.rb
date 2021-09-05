
#
# NeuroHub Project
#
# Copyright (C) 2021
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

# Helper for logging in using Globus identity stuff
class BoutiquesBootIntegrator

  def self.link_from_json_file(path)
# TODO validate JSON first
    descriptor   = BoutiquesSupport::BoutiquesDescriptor.new_from_file(path)
    tool_name    = descriptor.name
    tool_version = descriptor.tool_version
    myself       = RemoteResource.current_resource

    # Create Tool if necessary
    tool = Tool.create_from_descriptor(descriptor) # does nothing if it already exists
    # Create ToolConfig if necessary
    if myself.is_a?(Bourreau)
      ToolConfig.create_from_descriptor(myself, tool, descriptor) # does nothing if it already exists
    end

    # Register the descriptor with all existing tool_configs
    tool_configs = ToolConfig.register_descriptor(descriptor, tool_name, tool_version)
    if tool_configs.count > 0
      puts "Found #{tool_configs.count} ToolConfig(s) for #{path}"
    else
      puts "Warning: no ToolConfigs exist for descriptor #{path}"
    end
    puts " -> ToolName: #{tool_name} Version: #{tool_version}"

    # Create the Ruby class Xyz for the BoutiquesTask::Xyz
    klass_name       = descriptor.name_as_ruby_class # The Xyz part of BoutiquesTask::Xyz
    parent           = myself.is_a?(BrainPortal) ? BoutiquesPortalTask : BoutiquesClusterTask
    descriptor_class = descriptor.custom['cbrain:inherits-from-class'] # can be nil
    parent           = descriptor_class.constantize if descriptor_class.present?
    if BoutiquesTask.const_defined?(klass_name.to_sym) # check if already exists
      exist_superclass = BoutiquesTask.const_get(klass_name.to_sym).superclass
      if exist_superclass != parent
        cb_error "Conflict in superclass while integrating descriptor: BoutiquesTask::#{klass_name} has superclass #{exist_superclass} already, and wanted to set it to #{parent}"
      end
    else # Create new class BoutiquesTask::Xyz < ParentClass
      klass = Class.new(parent)
      BoutiquesTask.const_set klass_name.to_sym, klass
    end
  end

  def self.link_all(dir = CBRAIN::BoutiquesDescriptorsPlugins_Dir)
    jsons=Dir.glob(Pathname.new(dir) + "*.json")
    jsons.each do |json|
      self.link_from_json_file(json)
    end
  end

end
