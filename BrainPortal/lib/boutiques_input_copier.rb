
#
# CBRAIN Project
#
# Copyright (C) 2008-2024
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

#
# Some tools modify the cached version of the input directory.
#
# This can lead to some issues when the input is used multiple times
# on the same Bourreau and the cached version is already modified.
#
# To solve this issue, we can create a copy of the directory in the working
# directory and use this copy in the command line.
#
#     apptool [DIRECTORY_INPUT] ...
#
# with the following input in Boutiques:
#
#     {
#       "description": "A directory that contain the input data...",
#       "id": "parent_input_id",
#       "name": "Input",
#       "optional": true,
#       "type": "File",
#       "command-line-flag": "-i",
#       "value-key": "<-i input>"
#     },
#
# and in the `cbrain:integrator_modules` section look like:
#
#     "BoutiquesInputCopier": {
#       "parent_input_id": {"default": boolean, "hide": boolean, "description": string},
#      },
#
# The final command line will be:
#
#     apptool <-i input_copy>...
#
#
module BoutiquesInputCopier

  # Note: to access the revision info of the module,
  # you need to access the constant directly, the
  # object method revision_info() won't work.
  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:


  ############################################
  # Portal Side Modifications
  ############################################

  # Adjust the description for the input with the mention of
  # the fake parent directory information
  #
  # For each input in BoutiquesInputCopier section create a new entry in the descriptor
  # that will be a flag to choose if the input will be copied if the checkbox is selected
  def extension_of_descriptor(descriptor) #:nodoc:
    parent_input_ids = descriptor.custom_module_info('BoutiquesInputCopier')

    inputs      = descriptor["inputs"]

    # In parent_input_ids, select all non hidden inputs
    parent_input_ids = parent_input_ids.select { |_, config| !config["hide"] }
    copied_info = fill_copied_info(parent_input_ids, descriptor, inputs)

    # Add the new inputs to the descriptor and to the group if needed
    extracted_idx = copied_info.values.map { |info| info[:input_idx] }.sort.reverse

    extracted_idx.each do |index|
      # In copied_info, find the one with input_idx == index
      copied_info.each do |parent_inputid, info|
        next if info[:hide]
        next if info[:input_idx] != index

        # Insert the new input in the descriptor
        new_input = info[:new_input]
        inputs.insert(index, new_input)

        # Insert the new input in the group
        next if !info[:member_info]
        group        = descriptor.group_by_id(info[:member_info][:id])
        members      = group["members"]
        new_input_id = new_input["id"]
        next if members.include?(new_input_id)
        members.insert(info[:member_info][:idx], new_input_id)
      end
    end

    descriptor
  end

  def descriptor_for_before_form #:nodoc:
    descriptor = super.dup
    extension_of_descriptor(descriptor)
  end

  def descriptor_for_form #:nodoc:
    descriptor = super.dup
    extension_of_descriptor(descriptor)
  end

  def descriptor_for_after_form #:nodoc:
    descriptor = super.dup
    extension_of_descriptor(descriptor)
  end

  ############################################
  # Bourreau (Cluster) Side Modifications
  ############################################

  # For input in +BoutiquesInputCopier+ section,
  def setup #:nodoc:
    descriptor = self.descriptor_for_setup

    # First call the main setup
    return false if !super

    # Get the custom module info
    boutiques_input_copier = descriptor.custom_module_info('BoutiquesInputCopier')
    return true  if boutiques_input_copier.blank?

    invoke_params = self.invoke_params
    boutiques_input_copier.each do |parent_inputid, config|
      to_be_copied = self.invoke_params.delete("#{parent_inputid}_copy")

      # Special case if default-value is true and the field is hidden
      if to_be_copied.blank?
        to_be_copied = true if config["default-value"] && config["hide"]
      end

      # Skip if the copy option is not selected
      next if to_be_copied.blank? || to_be_copied == "0"

      userfile_id = invoke_params[parent_inputid]
      next if userfile_id.blank?
      userfile    = Userfile.find(userfile_id)
      copy_to                                        = userfile.name + "_" + self.run_id.to_s
      self.invoke_params[parent_inputid]             = copy_to
      descriptor.input_by_id(parent_inputid)["type"] = "String"

      rsync_cmd = "rsync -a -L --no-g --chmod=u=rwX,g=rX,Dg+s,o=r --delete #{userfile.name.bash_escape} #{copy_to.bash_escape}"
      rsyncout  = bash_this(rsync_cmd)
      cb_error "Failed to install '#{copy_to}';\nrsync reported: #{rsyncout}" unless rsyncout.blank?
    end

    true
  end

  ############################################
  # Utility Methods for the Module           #
  ############################################

  # Create copied_info with the following information:
  #   - idx_to_insert: index where the new input will be inserted
  #   - member_idx:    index of the member in the group
  def fill_copied_info(parent_input_ids, descriptor, inputs) #:nodoc:
    copied_info = {}

    parent_input_ids.each do |parent_inputid, config|
      parent_input = descriptor.input_by_id(parent_inputid) rescue nil

      next if parent_input.blank?
      next if parent_input["type"] != "File"

      # Get index of the input in the inputs array
      index  = inputs.index(parent_input)
      new_id = "#{parent_inputid}_copy"

      # Create a new input with the same properties as the original input
      new_input                  = parent_input.dup
      new_input["name"]          = "#{parent_input["name"]} (copy)"
      new_input["value-key"]     = "[#{parent_inputid}_copy]"
      new_input["type"]          = "Flag"
      new_input["id"]            = new_id
      new_input["description"]   = config["description"]   || "Copy the input in the working directory before running the command usefull when the input is modified by the command"
      new_input["default-value"] = config["default-value"] || false
      hide                       = config["hide"]          || false
      new_input.delete("command-line-flag")

      copied_info[parent_inputid] = { input_idx: index+1, new_input: new_input, hide: hide}
    end

    # Get the position in the groups where the new inputs will be inserted
    copied_info.each do |parent_inputid, info|
      descriptor.groups.each do |group|
        group["members"].each_with_index do |member, index|
          next if member != parent_inputid
          copied_info[parent_inputid][:member_info] = {idx: index + 1, id: group["id"]}
        end
      end
    end

    copied_info
  end

  # This utility method runs a bash +command+ , captures the output
  # and returns it. The user of this method is expected to have already
  # properly escaped any special characters in the arguments to the
  # command.
  def bash_this(command) #:nodoc:
    fh = IO.popen(command,"r")
    output = fh.read
    fh.close
    output
  end

  def copy_name_run_id(copy_to) #:nodoc:
    return copy_to + "_" + self.run_id.to_s
  end
end
