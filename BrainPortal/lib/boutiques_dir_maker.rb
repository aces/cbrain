
#
# CBRAIN Project
#
# Copyright (C) 2008-2023
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

require 'fileutils'

# Some tools expect that a directory e.g. results, etc exists in the working directory
#
# While traditionally we add to the boutiques command line prefix akin to 'mkdir -p [OUTPUT];'
# external collaborators might dislike polluting the command line with technical details
# and prefer a clean boutiques descriptor which does not create any new folders
# The the `cbrain:integrator_modules` section look like:
#
#     "BoutiquesDirMaker":
#          [ "[OUTDIR]", "[OUTDIR]/[THRESHOLD]_res", "tmp" ]
#
# Please avoid special characters save underscore and hyphen, and
# use relative paths. Boutiques templates (hereafter called patterns) are supported
#
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

    # Log revision information
    self.addlog("Creating directories with BoutiquesDirMaker.")
    basename = Revision_info.basename
    commit   = Revision_info.short_commit
    self.addlog("#{basename} rev. #{commit}")

    descriptor = self.descriptor_for_setup
    patterns   = descriptor.custom_module_info('BoutiquesDirMaker')

    # invoke overridden method
    commands = super
    return false if ! commands # early return

    substitutions_by_token  = descriptor.build_substitutions_by_tokens_hash(
      JSON.parse(File.read(self.invoke_json_basename))
    )

    # Process each directory pattern
    paths = patterns.map do |pattern|
      # Replace tokens
      path = descriptor.apply_substitutions(pattern, substitutions_by_token)

      if Pathname(path).absolute?
        self.addlog("BoutiquesDirMaker skips '#{pattern}', dir '#{path}', absolute paths are not supported")
        next
      end

      # replacing weird and special characters
      if path.gsub!(/[^0-9A-Za-z.\/\-_ ]+|(\.\.+)/, '_')
        self.addlog("Note that in '#{path}', underscore is used instead of special symbol(s)")
      end
      path
    end
    FileUtils.mkdir_p paths.compact
    commands
  end
end
