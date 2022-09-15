
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

# Some tools take expect that a file/directory input is
# placed input a parent directory.
#
# For example we have the following Boutiques command-line:
#
#     apptool [PRECOMPUTED_INPUT]
#
# with the following input in Boutiques:
#
#     {
#       "description": "A directory that contain the precomputed data process by...",
#       "id": "precomputed_input",
#       "name": "Precomputed input",
#       "optional": false,
#       "type": "File",
#       "value-key": "[PRECOMPUTED_INPUT]"
#     }
#
# and in the `cbrain:integrator_modules` section:
#
#     "BoutiquesDirMaker": {
#         "precomputed_input": "fake_parent_dir"
#      },
#
# In CBRAIN the user will select a userfile for example `sub-n`,
# the final command line will become:
#
#     apptool precomputed/sub-n
#
module BoutiquesDirMaker

  # Note: to access the revision info of the module,
  # you need to access the constant directly, the
  # object method revision_info() won't work.
  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  ############################################
  # Portal Side Modifications
  ############################################

  # Adjust the description for the input with the mention of
  # the fake parent directory
  def descriptor_for_form #:nodoc:
    descriptor = super.dup
    boutiques_dir_maker_list = descriptor.custom_module_info('BoutiquesDirMaker')

    boutiques_dir_maker_list.each do |inputid,dirname|
      # Adjust the description
      input        = descriptor.input_by_id(inputid)
      description  = input.description.presence || ""
      description += "\n" if description
      description += "This input will be copied in a parent folder `#{dirname}`.\n The parent folder will be used in the command line"
      input.description = description
    end

    descriptor
  end

  ############################################
  # Bourreau (Cluster) Side Modifications
  ############################################

  # For input in the `BoutiquesDirMaker` section,
  # create a directory based on the value BoutiquesDirMaker[input_id]
  # that will contains a symlink to the orginal selected Userfile.
  def setup #:nodoc:
    return false unless super

    descriptor = self.descriptor_for_setup
    self.addlog(descriptor.file_revision_info.format("%f rev. %s %a %d"))

    boutiques_dir_maker_list = descriptor.custom_module_info('BoutiquesDirMaker')
    descriptor.file_inputs.each do |input|
      userfile_id = invoke_params[input.id]
      next if userfile_id.blank? # that happens when it's an optional file
      userfile    = Userfile.find(userfile_id)
      dirname     = boutiques_dir_maker_list[input.id]

      # Most common situation
      if ! input.list || ! userfile.is_a?(CbrainFileList)
        make_available(userfile, dirname.present? ? "#{dirname}/#{userfile.name}" : userfile.name)
        next
      end

      # In case the input is a list and is assigned a CbrainFileList
      userfile.sync_to_cache
      userfile_list = userfile.userfiles_accessible_by_user!(user, nil, nil, file_access_symbol)
      userfile_list.compact.each do |subfile|
        make_available(subfile, subfile.name)
      end
    end

    true
  end

  # It adjusts the command-line of the descriptor.
  # So that the token for the parent directory is replaced by the
  # name of the parent directory we created in setup().
  #
  # From:
  #
  #   "command-line": "apptool [PRECOMPUTED_INPUT] [OUTPUT] stuff"
  #
  # To:
  #
  #   "command-line": "true [PRECOMPUTED_INPUT]; apptool #{parent_directory}/#{usefile.name} [OUTPUT] stuff"
  #
  # The reason a dummy true statement is prefixed at the beginning of the command
  # is so that bosh won't complain if it can't find the token [PRECOMPUTED_INPUT] anywhere
  # in the string.
  def descriptor_for_cluster_commands
    descriptor = super.dup

    command    = descriptor.command_line

    boutiques_dir_maker_list = descriptor.custom_module_info('BoutiquesDirMaker')
    boutiques_dir_maker_list.each do |inputid,dirname|
      input         = descriptor.input_by_id(inputid)
      token         = input.value_key # e.g. '[PRECOMPUTED_INPUT]'
      userfile_id   = invoke_params[inputid]
      userfile_name = Userfile.find(userfile_id).name

      # Make the substitution
      command = command.sub(token, "#{dirname}/#{userfile_name}")

      # In order to prevent bosh from complaining if the value-key is no longer found
      # anywhere in the command-line, we re-insert a dummy no-op bash statement at the
      # beginning of the command with at least one use of that value-key. It will look
      # like e.g.
      #
      #   "true [PRECOMPUTED_INPUT] ; real command here"
      #
      # In bash, the 'true' statement doesn't do anything and ignores all arguments.
      if ! command.include? token
        command = "true #{token} ; #{command}"
      end
    end

    descriptor.command_line = command
    descriptor
  end

end

