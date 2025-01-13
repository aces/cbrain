
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
# This can lead to issues when the input is used multiple times
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
# and in the `cbrain:integrator_modules` section, it looks like:
#
#     "BoutiquesInputCopier": {
#       "file_input_id": {"checkbox_selected": boolean, "checkbox_hidden": boolean, "checkbox_description": string},
#      },
#
# checkbox_selected:    boolean, true if the parent_input should be copied by default
# checkbox_hidden:      boolean, true if the select_box should be hidden in the form,
# if set to true the input_file will be copied in all case.
# checkbox_description: string, description of the checkbox input
#
# If "checkbox_hidden" is set to false, the checkbox will be added to the form
# to allow the user to choose if the input should be copied or not.
#
# If the checkbox is selected, the input will be copied in the working directory replacing the symlink
# previously created
#
#     apptool input_copy
#
# WARNING: Since this module create a copy of the input and remove
# the original symlink, it makes the task non-restartable. It will fail
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
    descriptor_with_added_checkboxes(super.dup)
  end

  def descriptor_for_form #:nodoc:
    descriptor_with_added_checkboxes(super.dup)
  end

  def descriptor_for_after_form #:nodoc:
    descriptor_with_added_checkboxes(super.dup)
  end

  ############################################
  # Bourreau (Cluster) Side Modifications
  ############################################

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
    if config["checkbox_hidden"]
      return true
    else
      return copy_value.to_s.match? /^(1|true)$/
    end
  end

  # Adjust the descriptor for the input with the mention of
  # the fake parent directory information
  #
  # For each input in BoutiquesInputCopier section create a new entry in the descriptor
  # that will be a flag to choose if the input will be copied if the checkbox is selected
  def descriptor_with_added_checkboxes(descriptor) #:nodoc:
    module_config = descriptor.custom_module_info('BoutiquesInputCopier')

    return descriptor if module_config.blank?

    # Add a checkbox for each input file
    module_config.each do |file_input_id,config|
      file_input        = descriptor.input_by_id(file_input_id)

      checkbox_hidden   = config["checkbox_hidden"].present?
      # If checkbox_hidden no need to add it to the form
      next if checkbox_hidden
      checkbox_selected = config["checkbox_selected"].present?
      checkbox_desc     = config["checkbox_description"].presence
      checkbox_id       = create_checkbox_id(file_input_id)

      checkbox_input = BoutiquesSupport::Input.new(
        :id             => checkbox_id,
        :type           => "Flag",
        :name           => "Full file copy of: #{file_input.name}",
        :description    => (checkbox_desc || "Make a full copy of the file in the working directory"),
        :optional       => file_input.optional.present?,
        "default-value" => checkbox_selected,
      )

      file_input_idx = descriptor.inputs.find_index { |input| input.id == file_input_id }
      descriptor.inputs.insert(file_input_idx+1, checkbox_input)

      descriptor.groups.each do |group|
        members        = group.members.dup
        file_input_idx = members.find_index(file_input_id)
        next unless file_input_idx
        members.insert(file_input_idx+1,checkbox_id) # this mutates directly in the group object
        group.members = members
      end
    end

    descriptor
  end

end

