
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

# Some tools expect that a file/directory input is
# placed in a parent directory.
#
# The parent dir will be used in the command line.
#
# For example we have the following Boutiques command-line:
#
#     apptool [PRECOMPUTED_INPUT] [DERIVATIVES_INPUT]
#
# with the following input in Boutiques:
#
#     {
#       "description": "A directory that contain the precomputed data process by...",
#       "id": "precomputed_input",
#       "name": "Precomputed input",
#       "optional": false,
#       "type": "File",
#       "command-line-flag": "--precomputed",
#       "value-key": "[PRECOMPUTED_INPUT]"
#     },
#     {
#       "description": "Data descriptor for precomputed data",
#       "id": "precomputed_data_descriptor_json",
#       "name": "Data descriptor (precomputed)",
#       "optional": false,
#       "type": "File"
#     },
#     {
#       "description": "A directory that contain the derivatives data process by...",
#       "id": "derivatives_input",
#       "name": "Derivatives input",
#       "optional": false,
#       "type": "File",
#       "command-line-flag": "--derivatives",
#       "value-key": "[DERIVATIVES_INPUT]"
#     }
#
# and in the `cbrain:integrator_modules` section look like:
#
#     "BoutiquesInputSubdirMaker": {
#       "input_id": {"dirname": "folder_name", "filename": "file_name", "append_filename": boolean},
#      },
#
# if the boolean is true the value used in the command line
# will be 'folder_name/userfile_name'. Otherwise the value will
# be 'folder_name' only.
#
# For example:
#
#     "BoutiquesInputSubdirMaker": {
#       "precomputed_input": {"dirname": "precomputed", "append_filename": false},
#       "precomputed_json" : {"dirname": "precomputed", "filename": "dataset_description.json", "append_filename": false},
#       "derivatives_input": {"dirname": "derivative",  "append_filename": true}
#      },
#
# In CBRAIN the user will select 3 userfiles for example:
#
# 'sub-n' for precomputed option.
# 'descriptor.json' for precomputed_data_descriptor_json option.
# 'sub-m' for derivatives option.
#
# The final command line will be:
#
#     apptool --precomputed precomputed --derivatives derivatives/sub-m
#
# The +precomputed+ folder contains +sub-n+ and +data_descriptor.json+ (== +descriptor.json+ renamed as +data_descriptor.json+)
# The +derivatives+ folder contains +sub-m+
#
module BoutiquesInputSubdirMaker

  # Note: to access the revision info of the module,
  # you need to access the constant directly, the
  # object method revision_info() won't work.
  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  ############################################
  # Portal Side Modifications
  ############################################

  # Adjust the description for the input with the mention of
  # the fake parent directory information
  def descriptor_for_form #:nodoc:
    descriptor                = super.dup
    parent_dirname_by_inputid = descriptor.custom_module_info('BoutiquesInputSubdirMaker')

    parent_dirname_by_inputid.each do |inputid,subdir_config|
      # Adjust the description
      input              = descriptor.input_by_id(inputid)
      dirname            = subdir_config["dirname"]
      filename           = subdir_config["filename"]
      input.description  = input.description.to_s +
                           "\nThis input will be copied in a parent folder: #{dirname}.\n The parent folder will be used in the command line."
      input.description  = input.description.to_s + "\nThe file will be registered with name #{filename}." if filename.present?
      end

    descriptor
  end

  ############################################
  # Bourreau (Cluster) Side Modifications
  ############################################

  # For input in +BoutiquesInputSubdirMaker+ section,
  # create a fake parent directory that will contains a symlink
  # to the orginal selected Userfile.
  def setup #:nodoc:
    original_userfile_ids = {}

    # Log revision information
    basename = Revision_info.basename
    commit   = Revision_info.short_commit
    self.addlog("Creating parent directories in BoutiquesInputSubdirMaker.")
    self.addlog("#{basename} rev. #{commit}")

    descriptor = self.descriptor_for_setup

    # Remove IDs from invoke_params
    parent_dirname_by_inputid = descriptor.custom_module_info('BoutiquesInputSubdirMaker')
    parent_dirname_by_inputid.each_key do |inputid|
      original_userfile_ids[inputid]  = invoke_params[inputid]
      invoke_params[inputid]          = nil
    end

    # invoke main setup
    result = super

    return false if ! super

    # Special make_available who need to have a parent folder
    parent_dirname_by_inputid.each do |inputid,subdir_config|
      userfile_id = original_userfile_ids[inputid]

      next if userfile_id.blank?

      userfile    = Userfile.find(userfile_id)
      dirname     = subdir_config["dirname"]
      filename    = subdir_config["filename"] || userfile.name

      make_available(userfile, "#{dirname}/#{filename}")
    end

    true
  ensure
    original_userfile_ids.each do |inputid, userfile_id|
      invoke_params[inputid] = original_userfile_ids[inputid]
    end
  end

  # Overrides the same method in BoutiquesClusterTask, as used
  # during cluster_commands()
  def finalize_bosh_invoke_struct(invoke_struct) #:nodoc:
    override_invoke_params = super.dup

    descriptor = self.descriptor_for_cluster_commands
    parent_dirname_by_inputid = descriptor.custom_module_info('BoutiquesInputSubdirMaker')
    parent_dirname_by_inputid.each do |inputid,subdir_config|
      if override_invoke_params[inputid].blank?
        override_invoke_params.delete(inputid)
      else
        dirname              = subdir_config["dirname"]
        filename             = subdir_config["filename"] || "#{override_invoke_params[inputid]}"
        append_userfile_name = subdir_config["append_filename"]
        override_invoke_params[inputid] = append_userfile_name ? "#{dirname}/#{filename}" : dirname
      end
    end

    override_invoke_params
  end

end
