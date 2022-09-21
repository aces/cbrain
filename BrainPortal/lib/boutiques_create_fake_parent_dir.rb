
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
#     "BoutiquesCreateFakeParentDir": ["precomputed_input"],
#
# In CBRAIN the user will select a userfile for example `sub-n`,
# the final command line will become:
#
#     apptool fake_parent_dir/sub-n
#
module BoutiquesCreateFakeParentDir

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
    descriptor                = super.dup
    parent_dirname_by_inputid = descriptor.custom_module_info('BoutiquesCreateFakeParentDir')

    parent_dirname_by_inputid.each do |inputid,fake_parent_dirname|
      fake_parent_dirname = fake_parent_dirname[0] if fake_parent_dirname.is_a?(Array)
      if !Userfile.is_legal_filename?(fake_parent_dirname)
        fake_parent_dirname = "fake_dir_uniq_id"
      end

      # Adjust the description
      input              = descriptor.input_by_id(inputid)
      input_description  = input.description || "";
      add_to_description = "This input will be copied in a parent folder `#{fake_parent_dirname}`.The parent folder will be used in the command line"

      input.description  = [input_description, add_to_description].compact.join("\n")
    end

    descriptor
  end

  def after_form
    after_form_msg = super
    return after_form_msg if self.errors.any?

    descriptor = descriptor_for_form
    parent_dirname_by_inputid = descriptor.custom_module_info('BoutiquesCreateFakeParentDir')

    params["BoutiquesCreateFakeParentDir"] = {}
    parent_dirname_by_inputid.each do |inputid,fake_parent_dirname|
      params["BoutiquesCreateFakeParentDir"][inputid] = invoke_params[inputid]
      invoke_params[inputid] = nil
    end

    after_form_msg
  end

  ############################################
  # Bourreau (Cluster) Side Modifications
  ############################################

  # For input in the `BoutiquesCreateFakeParentDir` section,
  # create a fake parent directory that will contains a symlink
  # to the orginal selected Userfile.
  def setup #:nodoc:
    return false unless super

    descriptor = self.descriptor_for_setup
    self.addlog(descriptor.file_revision_info.format("%f rev. %s %a %d"))

    parent_dirname_by_inputid = descriptor.custom_module_info('BoutiquesCreateFakeParentDir')

    parent_dirname_by_inputid.each do |inputid,fake_parent_dirname|
      userfile_id = params["BoutiquesCreateFakeParentDir"][inputid]
      next if userfile_id.blank?
      userfile    = Userfile.find(userfile_id)

      if !Userfile.is_legal_filename?(fake_parent_dirname)
        fake_parent_dirname = "fake_dir_#{userfile_id}"
      end

      params["BoutiquesCreateFakeParentDir"][inputid] = fake_parent_dirname
      make_available(userfile, "#{fake_parent_dirname}/#{userfile.name}")
    end

    true
  end

  # Overrides the same method in BoutiquesClusterTask, as used
  # during cluster_commands()
  def finalize_bosh_invoke_struct(invoke_struct) #:nodoc:
    self.params['BoutiquesCreateFakeParentDir'].each do |inputid, dirname|
      super[inputid] = dirname
    end

    super
  end
