
#
# CBRAIN Project
#
# Copyright (C) 2008-2021
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

# This module allows one to fix some of input parameters to specific values
# The fixed input(s) would no longer be shown to the user in the form.
#
# In the descriptor, the spec would look like:
#
#    "custom": {
#     "cbrain:integrator_modules": {
#         "BoutiquesInputValueFixer": {
#             "n_cpus": 1,
#             "mem": "4G",
#             "customquery": nil,
#             "level": "group"
#         }
#     }
# }
# COULD BE TRICKY, PRESENTLY PARAMETER DEPENDENCY are not supported
# disables-inputs, requires-inputs,
# the parameters assigned null will be disabled without assignment
# string 'null' is considered string for String params
module BoutiquesInputValueFixer

  # Note: to access the revision info of the module,
  # you need to access the constant directly, the
  # object method revision_info() won't work.
  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # the hash of param values to be fixed or be ommited ()  #
  def fixation
    fixation = self.boutiques_descriptor.custom_module_info('BoutiquesInputValueFixer')
    cb_error "module BoutiquesInputValueFixer requires a hash" unless fixation.is_a? Hash
    fixation
  end

  # deletes fixed inputs listed in the custom 'integrator_modules'
  # no input or values dependencies for fixed variables are fully supported,
  # in the presence of dependencies involving fixed params, the module
  # does its best to avoid deadlock and issues, but, probably,
  # might fails in edge cases. It is best if fixation is "closed" in the sense that
  # contains all the 'implied' fixation
  def delete_fixed_inputs(descriptor)

    # input parameters are marked by null values will be excluded from the command line
    # the major use case are Flags, but also may be useful to address params with 'default' (
    # or, for flags, null-like values)

    descriptor_dup = descriptor.dup
    skipped = fixation.keys.select do |i_id|
      begin
        input = descriptor_dup.input_by_id(i_id)
      rescue CbrainError # might be already deleted
        next
      end
      value = fixation[i_id]
      value.nil? || (input.type == 'Flag') &&  (value.presence.to_s.strip =~ /no|0|nil|none|null|false/i || value.blank?)

    end


    # generally speaking, boutiques inputs can have different dependencies,
    # here we address only group dependencies, namely mutually exclusion group
    # if not removed task UI might force user into entering invalid parameter valuation (invocation)

    descriptor_dup.groups.each do |g| # filter groups, relax restriction to anable form submission
      members = g.members - fixation.keys
      # disable a mutualy exclusive group if its param assigned fixed value by this modifier
      # if one simply deletes the fixed param,
      if g.mutually_exclusive && members.length != g.members.length # params can be mutually exclusive e.g. --use-min-mem vs --mem-mb
        if (fixation.keys & g.members - skipped).present? # at least some group members are actually assigned vals rather than deleted
          g.mutually_exclusive = false
          block_inputs(descriptor_dup, members)
          # a better solution is to delete rest of group params completely
          # a bit more complex though and might result in recursive code or nested loops
        end
      end

      # all-or-none is not reflected in dynamic gui, uncomment once fixed

      # removes  'one-is-required' or disables group when one or more element fixed, e.g.
      # if g.all_or_none && members.length != g.members.length
      #   # if (g.members & skipped).present?
      #   #   # todo delete all member inputs, or disable by injecting pairwise required/disable dependencie
      #   # end
      #   if (fixation.keys & g.members - skipped).present? # if one is set, rest should be to
      #     g.members.each do |i_id|
      #       begin
      #         input = descriptor.input_by_id(i_id)
      #       rescue CbrainError  # if descriptor was already processed
      #         next
      #       end
      #       input.optional = false
      #     end
      #   end
      # end

      # presently one-is-required is checked only statically, no GUI support
      # removes one-is-required flag if one element fixed
      # if g.one_is_required && members.length != g.members.length
      #   if (fixation.keys & g.members - skipped).present?
      #     g.one_is_required == false
      #   end
      # end

      g.members = members
    end
    descriptor_dup.groups = descriptor_dup.groups.select {|g| g.members.present? } # delete empty group

    # delete fixed inputs
    descriptor_dup.inputs = descriptor_dup.inputs.select { |i| ! fixation.key?(i.id) } # filter out fixed inputs

    # crude erase of fixed inputs from dependencies.
    #
    descriptor_dup.inputs.each do |i|
      i.requires_inputs = i.requires_inputs - fixation.keys if i.requires_inputs.present?
      i.disables_inputs = i.disables_inputs - fixation.keys if i.disables_inputs.present?
      i.value_requires.each { |v, a| i.value_disables[v] -= fixation.keys } if i.value_requires.present?
      i.value_disables.each { |v, a| i.value_disables[v] -= fixation.keys } if i.value_disables.present?
    end

    descriptor_dup
  end

  # this is blocks an input parameter, rather than explicitely deleting it
  # it is a bit unconvential yet expected to be used for relatively rare case when fixing or deleting
  # one input has implications.
  # Assuming the the boutiques developer(s) test their results
  def block_inputs(descriptor, input_ids)
    input_ids.each do |input_id|

      input = descriptor.input_by_id(input_id) rescue next
      #input.disables_if input.disables_inputs.present?
      input.disables_inputs ||= []
      input.disables_inputs |= [input_id]
      input.name += " --- disabled by admin ---"
    end
  end

  # adjust descriptor to allow check # of supplied files
  def descriptor_for_before_form

    delete_fixed_inputs(super)
  end

  # prevent from showing/submitting fixed inputs in the form
  def descriptor_for_form
    delete_fixed_inputs(super)
  end

  # show all the params
  def descriptor_for_show_params
    self.invoke_params.merge!(fixation) # show hidden parameters, used would not be able to edit them, so should be save
    super    # standard values
  end

  # validation step - the original boutiques with combined invocation, for the greatest accuracy
  # note, error messages might involve fixed variables
  def after_form
    self.invoke_params.merge!(fixation) # put back fixed values into invocation, if needed
    super    # Performs standard processing
  end

  # assuming the after_form always happens before cluster steps, the fixed values will be available for them

end
