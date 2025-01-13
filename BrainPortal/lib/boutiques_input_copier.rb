
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
#       "id": "file_input_id",
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
#       "file_input_id": {"select_box_selected": boolean, "select_box_hidden": boolean, "select_box_description": string},
#      },
#
# select_box_selected:    boolean, true if the parent_input should be copied by default
# select_box_hidden:      boolean, true if the select_box should be hidden in the form,
# if set to true the input_file will be copied in all case.
# select_box_description: string, description of the select_box input
#
# If "select_box_hidden" is set to false, a checkbox (select_box) will be added to the form
# to allow the user to choose if the input should be copied or not.
#
# If the checkbox is selected, the input will be copied in the working directory replacing the symlink
# previously created
#
#     apptool input_copy
#
# WARNING: Since this module create a copy of the input and remove
# the original symlink, it make the task not-restartable, it will fail
# during the setup phase of the restarted task if the input is already copied.
#
module BoutiquesInputCopier

  # Note: to access the revision info of the module,
  # you need to access the constant directly, the
  # object method revision_info() won't work.
  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:


  ############################################
  # Portal Side Modifications
  ############################################

  def descriptor_for_before_form #:nodoc:
    descriptor_with_special_input(super.dup)
  end

  def descriptor_for_form #:nodoc:
    descriptor_with_special_input(super.dup)
  end

  def descriptor_for_after_form #:nodoc:
    descriptor_with_special_input(super.dup)
  end

  ############################################
  # Bourreau (Cluster) Side Modifications
  ############################################

  # For input in +BoutiquesInputCopier+ section,
  def setup #:nodoc:
    # NOTE: This method is not restartable, if the input is already copied

    # Invoke main setup
    return false if !super

    descriptor = self.descriptor_for_setup

    # Get the custom module info
    boutiques_input_copier = descriptor.custom_module_info('BoutiquesInputCopier')
    basename = Revision_info.basename
    commit   = Revision_info.short_commit
    self.addlog("#{basename} rev. #{commit}")

    if boutiques_input_copier.blank?
      self.addlog("Configuration for BoutiquesInputCopier is blank, nothing to do.")
      return true
    end

    invoke_params         = self.invoke_params
    boutiques_input_copier.each do |parent_inputid, config|
      self.addlog("Handling copy of input: #{parent_inputid}")

      # Skip if no input is selected
      userfile_id = invoke_params[parent_inputid]
      if userfile_id.blank?
        self.addlog("No userfile found for #{parent_inputid}, skipping")
        next
      end


      # Skip if the copy option is not selected
      copy_id    = create_checkbox_id(parent_inputid)
      copy_value = invoke_params[copy_id]
      to_copy    = need_to_copy(copy_value, config)
      if !to_copy
        self.addlog("No need to copy for #{parent_inputid}, skipping")
        next
      end

      # Determine the name of the copy
      userfile                 = Userfile.find(userfile_id)
      userfile_name            = userfile.name

      userfile_path            = File.realpath(userfile_name) # Verifie ce qui est dans le workdir
      userfile_cache_full_path = userfile.cache_full_path     # La valeur dans le userfile.

      if !File.symlink?(userfile_name)
        cb_error("Original userfile is not a symlink: #{userfile_name}, skipping.")
      end

      if  userfile_cache_full_path.to_s != userfile_path.to_s
        cb_error("Path of cache is inconsistent for #{userfile_name}, skipping.")
      end

      # Remove the userfile from the working directory
      File.delete(userfile_name) if File.exist?(userfile_name)

      rsync_cmd = "rsync -a -L --no-g --chmod=u=rwX,g=rX,Dg+s,o=r --delete #{userfile_path} #{self.full_cluster_workdir} 2>&1"
      # self.addlog("Running: #{rsync_cmd}")
      rsyncout  = bash_this(rsync_cmd)

      unless rsyncout.blank?
        File.rm_rf(userfile_name) if File.exist?(userfile_name)
        cb_error "Failed to rsync #{userfile.name} reported: #{rsyncout}" unless rsyncout.blank?
      end
    end

    true
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

  # Overrides the same method in BoutiquesClusterTask, as used
  # during cluster_commands()
  def finalize_bosh_invoke_struct(invoke_struct) #:nodoc:
    override_invoke_params = super.dup

    descriptor             = self.descriptor_for_cluster_commands
    boutiques_input_copier = descriptor.custom_module_info('BoutiquesInputCopier')

    # For each input in BoutiquesInputCopier override the input with the copy
    # if the checkbox is selected
    boutiques_input_copier.keys.each do |parent_inputid|
      override_invoke_params.delete(create_checkbox_id(parent_inputid))
    end

    override_invoke_params
  end

    # Utility Methods for the Module
  ############################################

  def create_checkbox_id(parent_inputid) #:nodoc:
    "#{parent_inputid}_bic_copy"
  end

  def need_to_copy(copy_value, config) #:nodoc:
    # Special case if default-value is true and the field is hidden
    if config["select_box_hidden"]
      return true
    else
      return copy_value.to_s.match? /^(1|true)$/
    end
  end

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
      new_id = create_checkbox_id(parent_inputid)

      # Create a new input with the same properties as the original input
      new_input                  = parent_input.dup
      new_input["name"]          = "#{parent_input["name"]} (copy)"
      new_input["value-key"]     = "[#{new_id}]"
      new_input["type"]          = "Flag"
      new_input["id"]            = new_id
      new_input["description"]   = config["select_box_description"] || "Copy the input in the working directory before running the command usefull when the input is modified by the command"
      new_input["default-value"] = config["select_box_selected"]    || false
      hide                       = config["select_box_hidden"]      || false
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

  # Adjust the descriptor for the input with the mention of
  # the fake parent directory information
  #
  # For each input in BoutiquesInputCopier section create a new entry in the descriptor
  # that will be a flag to choose if the input will be copied if the checkbox is selected
  def descriptor_with_special_input(descriptor) #:nodoc:
    parent_input_ids = descriptor.custom_module_info('BoutiquesInputCopier')

    # In parent_input_ids, select all non hidden inputs
    inputs           = descriptor.inputs
    parent_input_ids = parent_input_ids.select { |_, config| !config["select_box_hidden"] }
    copied_info      = fill_copied_info(parent_input_ids, descriptor, inputs)

    # Add the new inputs to the descriptor and to the group if needed
    extracted_idx = copied_info.values.map { |info| info[:input_idx] }.sort.reverse

    extracted_idx.each do |index|
      # In copied_info, find the one with input_idx == index
      copied_info.each do |parent_inputid, info|
        next if info[:select_box_hidden]
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


end