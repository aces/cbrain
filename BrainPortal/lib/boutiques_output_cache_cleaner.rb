
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

# This module adds automatic cleaning up of the cached
# files created for the outputs of the task.
#
# To include the module automatically at boot time
# in a task integrated by Boutiques, add a new entry
# in the 'custom' section of the descriptor, like this:
#
#   "custom": {
#       "cbrain:integrator_modules": {
#           "BoutiquesOutputCacheCleaner": [ "my_output1", "my_output2" ]
#       }
#   }
#
# In this example, any CBRAIN userfile outputs created by the Boutiques
# outputs named 'my_output1' and 'my_output2' will have their local caches
# erased when the task is finished successfully. This is useful
# when processing large datasets creating large outputs that are sent
# to a remote location, and so there is no need to keep a local copy
# after the transfer is done.
module BoutiquesOutputCacheCleaner

  # Note: to access the revision info of the module,
  # you need to access the constant directly, the
  # object method revision_info() won't work.
  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # This method takes a descriptor and adds a new
  # fake input checkbox, in a group at the bottom of all the other
  # input groups. This means the user interface allow the
  # user to disable this module's core function.
  def descriptor_with_special_input(descriptor)
    descriptor = descriptor.dup

    # Add new input
    new_input = BoutiquesSupport::Input.new(
      "name"          => "Enable Output Cache Cleaning",
      "id"            => "cbrain_enable_output_cache_cleaner",
      "description"   => "If set, the cached content of produced outputs are erased when the task completes successfuly.",
      "type"          => "Flag",
      "optional"      => false,
      "default-value" => true,
    )
    descriptor.inputs << new_input

    # Add new group with that input
    groups       = descriptor.groups || []
    cb_mod_group = groups.detect { |group| group.id == 'cbrain_modules_options' }
    if cb_mod_group.blank?
      cb_mod_group = BoutiquesSupport::Group.new(
        "name"        => 'CBRAIN Modules Options',
        "id"          => 'cbrain_modules_options',
        "description" => 'Special options provided by CBRAIN integration modules',
        "members"     => [],
      )
      groups << cb_mod_group
    end
    cb_mod_group.members << new_input.id

    descriptor.groups = groups
    descriptor
  end

  def descriptor_for_form #:nodoc:
    descriptor_with_special_input(super)
  end

  def descriptor_for_before_form #:nodoc:
    descriptor_with_special_input(super)
  end

  def descriptor_for_after_form #:nodoc:
    descriptor_with_special_input(super)
  end

  # After the user clicks 'submit' to launch the task,
  # if everything is ok, we move the value of the checkbox
  # that enables this module into the main params structure
  # (and thus remove it from the 'invoke' substructure), because
  # this is not a real parameter of the tool. The tool bosh
  # would complain if we left it there.
  def after_form #:nodoc:
    message = super
    return message if params_errors.present? || errors.present?
    enabled = self.invoke_params.delete :cbrain_enable_output_cache_cleaner
    self.params[:cbrain_enable_output_cache_cleaner] = (enabled.to_s.match? /^(1|true)$/)
    message
  end

  def save_results #:nodoc:

    # Call all the normal code
    return false unless super

    # Is this module's functionality enabled?
    # This is controlled by a new fake input checkbox in the form. See above.
    return true unless self.params[:cbrain_enable_output_cache_cleaner]

    # Log version of this module
    self.addlog("BoutiquesOutputCacheCleaner rev. #{Revision_info.short_commit}")

    # Get the list of outputs to clean from the descriptor
    descriptor = self.descriptor_for_save_results
    output_ids = descriptor.custom_module_info('BoutiquesOutputCacheCleaner')

    # Get the userfile IDs of all outputs.
    # The Boutiques integrator create arrays of userfile
    # IDs in the task's params, in entries named like
    # "_cbrain_output_{BTQ_INPUT_ID}"
    output_ids.each do |output_id|
      userfile_ids = self.params["_cbrain_output_#{output_id}"]
      next if userfile_ids.blank?  # empty array or nil
      Array(userfile_ids).each do |userfile_id|
        userfile = Userfile.where(:id => userfile_id).first
        if userfile
          self.addlog "Erasing cached content for output file '#{userfile.name}'"
          userfile.cache_erase
        end
      end
    end

    true
  end

end
