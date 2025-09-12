
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

# This module will attempt to force an output file
# created by the boutiques integrator to be stored
# with a "browse_path" under the target destination
# DataProvider, if possible. e.g.
#
#    "custom": {
#        "cbrain:integrator_modules": {
#            "BoutiquesForcedOutputBrowsePath" : {
#              "supertool_output_dir":  "derivatives/supertool",
#              "supertool_html_report": "reports/[VERSION]/supertool",
#            },
#        }
#    }
#
# The keys are IDs of the output-files section of the descriptor,
# and the values are relative paths on the target result DP.
# The relative paths can contain templated values that will be
# substituted when the results are saved.
#
# If the target DP doesn't have browse_path capabilities, the
# browse path will be set to nil and a warning will be added
# to the task's log.
module BoutiquesForcedOutputBrowsePath

  # Note: to access the revision info of the module,
  # you need to access the constant directly, the
  # object method revision_info() won't work.
  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  ##################################################
  # Cluster side overrides
  ##################################################

  # This method overrides the method in BoutiquesClusterTask.
  # If the name for the file contains a relative path such
  # as "a/b/c/hello.txt", it will extract the "a/b/c" and
  # provide it in the browse_path attribute to the Userfile
  # constructor in super().
  def safe_userfile_find_or_new(klass, attlist)
    name = attlist[:name]
    return super(klass, attlist) if ! (name.include? "/") # if there is no relative path, just do normal stuff

    # Find all the info we need
    attlist = attlist.dup
    dp_id   = attlist[:data_provider_id] || self.results_data_provider_id
    dp      = DataProvider.find(dp_id)
    pn      = Pathname.new(name)  # "a/b/c/hello.txt"

    # Make adjustements to name and browse_path
    attlist[:name] = pn.basename.to_s  # "hello.txt"
    if dp.has_browse_path_capabilities?
      attlist[:browse_path] = pn.dirname.to_s   # "a/b/c"
      self.addlog "BoutiquesForcedOutputBrowsePath: result DataProvider browse_path will be '#{pn.dirname}'"
    else
      attlist[:browse_path] = nil # ignore the browse_path
      self.addlog "BoutiquesForcedOutputBrowsePath: result DataProvider doesn't have multi-level capabilities, ignoring forced browse_path '#{pn.dirname}'."
    end

    # Invoke the standard code
    return super(klass, attlist)
  end

  # This method overrides the method in BoutiquesClusterTask.
  # After running the standard code, it will prepend a
  # browse path to the "name" returned to the caller.
  # Note that this kind of modification should really happen
  # only AFTER any other overrides to this method (e.g. what
  # happens in the other module BoutiquesOutputFilenameRenamer )
  def name_and_type_for_output_file(output, pathname)
    dest_supports_browse_path = self.data_provider.has_browse_path_capabilities?
    if self.getlog.to_s !~ /BoutiquesForcedOutputBrowsePath rev/
      self.addlog("BoutiquesForcedOutputBrowsePath rev. #{Revision_info.short_commit}") # only log this once
      self.addlog("BoutiquesForcedOutputBrowsePath: result DataProvider doesn't have multi-level capabilities, ignoring all forced browse_path configured by the descriptor.") if ! dest_supports_browse_path
    end
    name, type  = super # the standard names and types; the name will be replaced
    return [ name, type ] if ! dest_supports_browse_path # when ignoring it all
    descriptor  = descriptor_for_save_results
    config      = descriptor.custom_module_info('BoutiquesForcedOutputBrowsePath') || {}
    browse_path = config[output.id]  # "a/b/c"
    return [ name, type ] if browse_path.blank? # no configured browse_path for this output
    browse_path = apply_value_keys(browse_path) # replaces [XYZ] strings with values from params
    combined    = (Pathname.new(browse_path) + name).to_s # "a/b/c/name"
    [ combined, type ]
  end

  # Returns a modified version of browse_path where the
  # substrings [XYZ] are replaced by the value-keys of
  # the invoke structure.
  def apply_value_keys(browse_path)
    descriptor = self.descriptor_for_save_results

    # Prepare the substitution hash
    substitutions_by_token  = descriptor.build_substitutions_by_tokens_hash(
                                JSON.parse(File.read(self.invoke_json_basename))
                              )

    new_browse_path = descriptor.apply_substitutions(browse_path, substitutions_by_token)

    new_browse_path
  end

end
