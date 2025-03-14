
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


# Some tools expect that a directory e.g. results, etc exists in the working directory
#
# While in a descriptor's command line can include a prefix 'mkdir -p DIRNAME;' for that purpose,
# creating multiple directories  makes the command line harder to read and maintain. 
#
# This utility # allows the creation auxiliary sub-directories without using command line.
# 
# The the `cbrain:integrator_modules` section look like:
#
#     "cbrain:integrator_modules": {
#        "BoutiquesDirMaker": [
#           "[OUTDIR]",
#           "[OUTDIR]/[THRESHOLD]_res",
#           "[OUTDIR]/[THRESHOLD]_res/info",
#           "tmp"
#        ]
#
# Please avoid single or double dots, spaces and special characters, except underscore and hyphen.
# Use relative paths only. 
#
# Boutiques templates (aka patterns) are supported and always substituted.
#
# Nested directories should be created step by step, as demonstrated with [OUTDIR]/[THRESHOLD]_res/info 
# in the snippet above.

module BoutiquesDirMaker

  # Note: to access the revision info of the module,
  # you need to access the constant directly, the
  # object method revision_info() won't work.
  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  ############################################
  # Bourreau (Cluster) Side Modifications
  ############################################

  # create few sub directories in the work folder
  def cluster_commands #:nodoc:
    # invoke overridden method
    commands = super

    descriptor = self.descriptor_for_setup
    patterns   = descriptor.custom_module_info('BoutiquesDirMaker')
    return commands if patterns.blank?

    # Log revision information
    commit = Revision_info.short_commit
    self.addlog("Creating auxiliary directories with BoutiquesDirMaker rev. #{commit}.")

    substitutions_by_token  = descriptor.build_substitutions_by_tokens_hash(
      JSON.parse(File.read(self.invoke_json_basename))
    )

    # Process each directory pattern
    patterns.each do |pattern|
      path = descriptor.apply_substitutions(pattern, substitutions_by_token)
      path = path.strip  # whitespaces in dir names are not supported
      path = Pathname.new(path.strip).cleanpath  # normalizing: removing unnecessary dots ...
      cb_error "BoutiquesDirMaker cannot create path '#{path}' (pattern '#{pattern}')." if path.to_s.start_with?('.')
      safe_mkdir(path)
      self.addlog("BoutiquesDirMaker created '#{path}'.")
    end
    commands
  end
end
