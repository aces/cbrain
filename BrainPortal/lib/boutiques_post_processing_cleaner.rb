
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

# This module adds automatic cleaning of files or
# directories inside the task's work directory after
# the task has completed successfully.
# What to clean can be specified by boutiques patterns
# (e.g. inputs that contain "value-key" entries)
# or by file patterns (standard globbing).
#
# To include the module automatically at boot time
# in a task integrated by Boutiques, add a new entry
# in the 'custom' section of the descriptor, like this:
#
#   "custom": {
#       "cbrain:integrator_modules": {
#           "BoutiquesPostProcessingCleaner": [
#             "work",
#             "*.tmp",
#             "[OUTFILE_NAME].*.work"
#           ]
#       }
#   }
#
# This module will also erase EXT3 capture filesystems created by CBRAIN
# if the basename of the filesystem, as configured in the ToolConfig, matches
# one of the entries in this module's configuration. So in the code above,
# the content of the file ".capt_work.ext3" would also be erased if a capture
# filesystem was configured for "work". Patterns are not supported for
# this feature.
#
module BoutiquesPostProcessingCleaner

  # Note: to access the revision info of the module,
  # you need to access the constant directly, the
  # object method revision_info() won't work.
  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # This method overrides the one in BoutiquesClusterTask
  def save_results

    # Performs standard processing
    return false unless super

    # Get the cleaning paths patterns from the descriptor
    descriptor = self.descriptor_for_save_results
    patterns   = descriptor.custom_module_info('BoutiquesPostProcessingCleaner')

    # Prepare the substitution hash
    substitutions_by_token  = descriptor.build_substitutions_by_tokens_hash(
                                JSON.parse(File.read(self.invoke_json_basename))
                              )

    # Process each pattern
    patterns.each do |pattern|
      # Replace tokens
      subpattern = descriptor.apply_substitutions(pattern, substitutions_by_token)
      # Find filesystem entries
      paths      = Dir.glob(subpattern)
      self.addlog("No cleanup required for pattern '#{pattern}'") if paths.empty?
      # Send them to hell
      paths.each do |path|
        if ! self.path_is_in_workdir?(path)
          self.addlog("Cleaning path '#{path}' is outside of work directory, skipped")
          next
        end
        self.addlog("Cleaning up '#{path}' in work directory")
        system("/bin/rm","-rf",path)
      end
    end

    # Also erase ext3 catpure files IF they match one of the patterns
    ext3capture_basenames.each do |basename, _|
      next unless patterns.include?(basename) # must be exact match, e.g. 'work' == 'work'
      fs_name = ".capt_#{basename}.ext3"      # e.g. .capt_work.ext3, see also in cluster_task.rb
      next unless File.file?(fs_name)
      self.addlog("Cleaning up EXT3 capture filesystem '#{fs_name}' in work directory")
      File.delete(fs_name) rescue nil
    end

    true
  end

end
