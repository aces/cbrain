
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

#
# Some tools modify their own inputs in place. Given
# CBRAIN prepares all inputs in a cache directory where
# several tasks are able to access them in parallel, we
# need to force these tools to make a private copy of their
# inputs before they run.
#
# This module can be configured in a Boutiques descriptor to
# implement this functionality. For any input file, the
# integrator can force the copying to occur, or can provide
# the user with the ability to choose whether or not to trigger
# the copying (if they know what they are doing) with a new
# check box in the CBRAIN form.
#
# Given an input file defined in the descriptor such as this:
#
#   {
#     "description": "A directory that contain the input data...",
#     "id": "file_input_id",
#     "type": "File",
#     "name": "The super data file",
#     "optional": true,
#   }
#
# then in the custom "cbrain:integrator_modules" section this module can
# be configured like this (in pseudo JSON):
#
#   "custom": {
#     "cbrain:integrator_modules": {
#       "BoutiquesInputCopier": {
#         "file_input_id": {
#           "checkbox_selected": <boolean>,
#           "checkbox_hidden": <boolean>,
#           "checkbox_description": "string"
#         },
#         <configs for other inputs>
#       }
#     }
#   }
#
# Each file input being copied is configured with three arguments:
#
# checkbox_selected: boolean; if set to true, the form's checkbox will
# be already 'checked' by default. This option only makes sense if the
# checkbox is not hidden.
#
# checkbox_hidden: boolean; if set to true the select box will not even
# be shown to the user in the CBRAIN task form. This implies the
# file's copying will be performed unconditionally.
#
# checkbox_description: string, description of the checkbox input; if not
# provided an internal description is generated.
#
# If the users enables the checkbox, the input will be copied in the working directory
# replacing the symlink previously created by the standard CBRAIN framework.
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
    module_config = descriptor.custom_module_info('BoutiquesInputCopier')
    basename = Revision_info.basename
    commit   = Revision_info.short_commit
    self.addlog("#{basename} rev. #{commit}")

    if module_config.blank?
      self.addlog("Configuration for BoutiquesInputCopier is blank, nothing to do.")
      return true
    end

    invoke_params = self.invoke_params

    module_config.each do |parent_inputid, config|
      self.addlog("#{basename}: handling copy of input '#{parent_inputid}'")

      # Skip if no input is selected
      userfile_id = invoke_params[parent_inputid]
      if userfile_id.blank?
        self.addlog("#{basename}: no input files provided for '#{parent_inputid}', skipping")
        next
      end

      # The only value with need from config in this method
      checkbox_hidden  = config["checkbox_hidden"]

      # Skip if the copy option is not selected
      checkbox_id      = create_checkbox_id(parent_inputid)
      checkbox_checked = invoke_params[checkbox_id]

      # We skip if (the checkbox is SHOWN) *AND* (the user DID NOT SELECT IT)
      # We COPY in all other cases.
      if checkbox_hidden.blank? && (checkbox_checked.blank? || checkbox_checked == "0")
        self.addlog("#{basename}: no need to copy for #{parent_inputid}, skipping")
        next
      end

      # Copy code starts here.
      # Determine the name of the copy
      userfile                 = Userfile.find(userfile_id)
      userfile_name            = userfile.name

      userfile_path            = File.realpath(userfile_name) # Resolves symlink in workdir
      userfile_cache_full_path = userfile.cache_full_path     # Path in cache

      if ! File.symlink?(userfile_name)
        cb_error("#{basename}: original userfile is not a symlink: '#{userfile_name}'.")
      end

      if userfile_cache_full_path.to_s != userfile_path.to_s
        cb_error("#{basename}: path of cache and workdir are inconsistent for '#{userfile_name}'.")
      end

      self.addlog("#{basename}: Copy input for '#{userfile_name}' in task work directory")

      # Remove the userfile from the working directory
      File.delete(userfile_name)

      rsync_cmd = "rsync -a -L --no-g --chmod=u=rwX,g=rX,Dg+s,o=r --delete #{userfile_cache_full_path.to_s.bash_escape} #{self.full_cluster_workdir.to_s.bash_escape} 2>&1"
      # self.addlog("Running: #{rsync_cmd}")
      rsyncout  = bash_this(rsync_cmd)

      unless rsyncout.blank?
        File.rm_rf(userfile_name) if File.exist?(userfile_name)
        cb_error "Failed to copy '#{userfile.name}'; rsync reported: #{rsyncout}"
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

    descriptor    = self.descriptor_for_cluster_commands
    module_config = descriptor.custom_module_info('BoutiquesInputCopier')

    # For each input in BoutiquesInputCopier override the input with the copy
    # if the checkbox is selected
    module_config.keys.each do |parent_inputid|
      override_invoke_params.delete(create_checkbox_id(parent_inputid))
    end

    override_invoke_params
  end

  ############################################
  # Utility Methods for the Module
  ############################################

  def create_checkbox_id(parent_inputid) #:nodoc:
    "#{parent_inputid}_bic_copy"
  end

  # Adjust the descriptor for the input with the mention of
  # the fake parent directory information
  #
  # For each input in BoutiquesInputCopier section create a new entry in the descriptor
  # that will be a flag to choose if the input will be copied if the checkbox is selected
  def descriptor_with_added_checkboxes(descriptor) #:nodoc:
    module_config = descriptor.custom_module_info('BoutiquesInputCopier')

    return descriptor if module_config.blank?

    # Add a checkbox for each input file modified by the module
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

      # Insert the checkbox just below the File input
      file_input_idx = descriptor.inputs.find_index { |input| input.id == file_input_id }
      descriptor.inputs.insert(file_input_idx+1, checkbox_input)

      # Insert the checkbox just below the File input in each group, if any.
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

