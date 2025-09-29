
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

# This class implements the boot-time loading of Boutiques descriptors
# located in the installed plugins directory CBRAIN::BoutiquesDescriptorsPlugins_Dir
#
# All descriptors are loaded once, and saved in a global cache managed by
# the ToolConfig class.
#
# At the same time, whenever a descriptor is loaded, a Tool will be created if it doesn't already exist
# when booting a Portal, and a ToolConfig will be created when booting a Bourreau.
class BoutiquesBootIntegrator

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def self.link_from_json_file(path)
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
    # This is a runtime global cache that associates [tool_name, tool_version] -> descriptor
    tool_configs = ToolConfig.register_descriptor(descriptor, tool_name, tool_version)

    # Create the Ruby class Xyz for the BoutiquesTask::Xyz
    klass_name       = descriptor.name_as_ruby_class # The Xyz part of BoutiquesTask::Xyz
    parent           = myself.is_a?(BrainPortal) ? BoutiquesPortalTask : BoutiquesClusterTask
    descriptor_class = descriptor.custom['cbrain:inherits-from-class'] # can be nil
    parent           = descriptor_class.constantize if descriptor_class.present?
    klass            = nil

    # It's ok to have several descriptor wanting the same implementation
    # class (e.g. several versions of the tool) but only if all the superclasses agree too.
    if BoutiquesTask.const_defined?(klass_name.to_sym) # check if already exists
      exist_superclass = BoutiquesTask.const_get(klass_name.to_sym).superclass
      if exist_superclass != parent
        cb_error "Conflict in superclass while integrating descriptor: BoutiquesTask::#{klass_name} has superclass #{exist_superclass} already, and wanted to set it to #{parent}"
      end
      klass = BoutiquesTask.const_get(klass_name.to_sym)
    else
      # Create new class. This is the equivalent of
      #   class BoutiquesTask::Xyz < ParentClass
      #   end
      # This class is pretty much empty of any distinct code.
      # The real meat is in ParentClass.
      klass = Class.new(parent)
      BoutiquesTask.const_set klass_name.to_sym, klass
      klass.const_set :Revision_info, CbrainFileRevision[__FILE__]
    end

    # Add special module functionality if necessary
    framework_methods = BoutiquesPortalTask.instance_methods | BoutiquesClusterTask.instance_methods
    seen_methods      = {}  # method_name => module_name; to detect conflicts
    custom_modules = descriptor.custom['cbrain:integrator_modules'] || {}
    custom_modules.keys.each do |modname|   # "MySuperModule"
      mod        = modname.constantize
      modmethods = mod.instance_methods - framework_methods # all local methods of the module
      modmethods.each do |method|
        if ! seen_methods[method]
          seen_methods[method] = modname
          next
        end
        cb_error "Method conflict detected: module '#{modname}' implements method '#{method}' which will hide the method of the same name in module '#{seen_methods[method]}'"
      end
      klass.include(mod)                    # like 'include MySuperModule'
    end

    # Boot process messages
    basename = Pathname.new(path).basename
    puts "B> Boutiques JSON: #{basename} Class: #{klass_name} Tool: #{tool_name} ToolConfigs: #{tool_configs.count}"
  rescue => ex
    Rails.logger.error(
      "An error occured while trying to integrate descriptor '#{path}'"
    )
    raise ex
  end

  # This method scans a directory for JSON boutiques descriptors and
  # loads them all.
  def self.link_all(dir = CBRAIN::BoutiquesDescriptorsPlugins_Dir)
    jsons=Dir.glob(Pathname.new(dir) + "*.json").sort
    jsons.each do |json|
      self.link_from_json_file(json)
    end
  end

end
