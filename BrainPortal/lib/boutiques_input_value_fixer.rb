
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
#        "cbrain:integrator_modules": {
#            "BoutiquesInputValueFixer": {
#               "n_cpus": 1,
#               "mem": "4G",
#               "customquery": null,
#               "level": "group"
#         }
#     }
#
# It is recommended to supply fixed_values in the specification is "closed" in the sense that
# contains all the parameter that depend on the fixed, that is participate in input-requires,
# value-requires, input-disables, value-disables, and address the group constraints.
# Otherwise the module will do it automatically, yet
# the present solution is crude, and does not guaranty optimal results.
# Some nuances can be lost.
# This is because our main use-case
# is resource control parameter, which seldom involve dependencies.
#
module BoutiquesInputValueFixer

  # Note: to access the revision info of the module,
  # you need to access the constant directly, the
  # object method revision_info() won't work.
  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:


  # the hash of param values to be fixed or be omited ()  #
  def fixed_values
    self.boutiques_descriptor.custom_module_info('BoutiquesInputValueFixer')
  end

  # deletes fixed inputs listed in the custom 'integrator_modules'
  def descriptor_without_fixed_inputs(descriptor)
    # input parameters are marked by null values will be excluded from the command line
    # the major use case are Flags, but also may be useful to address params with 'default'

    fixed_input_ids = fixed_values.keys
    descriptor_dup = descriptor.dup
    fully_removed = fixed_values.keys.select do |i_id|  # this variables are flagged to be removed rather than assigned value
                                                   # in the spec, so they will be treated slightly different
      input = descriptor_dup.input_by_id(i_id)
      value = fixed_values[i_id]
      value.nil? || (input.type == 'Flag') &&  (value.presence.to_s.strip =~ /no|0|nil|none|null|false/i || value.blank?)
      deep_copy
    end

    # generally speaking, boutiques input groups can have three different constraints,
    # here we address mutually exclusion group only, which is the only one present in dynamic GUI (rest are evaluated
    # after submission of parameter).

    descriptor_dup.groups.each do |g| # filter groups, relax restriction to ensure that form can still be submitted
      members = g.members - fixed_values.keys
      # disable a mutualy exclusive group if its param assigned fixed value by this modifier
      # if one simply deletes the fixed param,
      if g.mutually_exclusive && members.length != g.members.length # params can be mutually exclusive e.g. --use-min-mem vs --mem-mb
        if (fixed_input_ids & g.members - fully_removed).present? # at least some group members are actually assigned vals rather than deleted
          g.mutually_exclusive = false
          if g.one_is_required.present?
            g.one_is_required = false
          end
          block_inputs(descriptor_dup, members)
        end
      end


      # all-or-none is not reflected in dynamic gui, and used less often
      # perhaps address once gui extended to
      # support all the constraints

      # yet in the case the constraint added by somebody who unfamiliar or forgot to remove
      # this in the case the dynamic validation is enabled for one is required, when
      # mishandled this constraint might create big troubles



      # removes  'one-is-required' or disables group when one or more element fixed, e.g.
      # if g.all_or_none && members.length != g.members.length
      #   # if (g.members & fully_removed).present?
      #   #   # todo delete all member inputs, or disable by injecting pairwise required/disable dependencies
      #   # end
      #   if (fixed_values.keys & g.members - fully_removed).present? # if one is set, rest should be to
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

      # presently one-is-required is checked only statically, yet
      # enabling the GUI support to that constraint my cause issues.
      # removes one-is-required flag if one element fixed
      # if g.one_is_required || g.&& members.length != g.members.length
      #   if (fixed_values.keys & g.members - fully_removed).present?
      #     g.one_is_required == false
      #   end
      # end

      g.members = members
    end
    descriptor_dup.groups = descriptor_dup.groups.select {|g| g.members.present? } # delete empty group

    # delete fixed inputs
    descriptor_dup.inputs = descriptor_dup.inputs.select { |i| ! fixed_values.key?(i.id) } # filter out fixed inputs

    # crude erase of fixed inputs from dependencies.
    descriptor_dup.inputs.each do |i|
      i.requires_inputs = i.requires_inputs - fixed_values.keys if i.requires_inputs.present?
      i.disables_inputs = i.disables_inputs - fixed_values.keys if i.disables_inputs.present?
      i.value_requires.each { |v, a| i.value_requires[v] -= fixed_values.keys } if i.value_requires.present?
      i.value_disables.each { |v, a| i.value_disables[v] -= fixed_values.keys } if i.value_disables.present?
    end

    descriptor_dup
  end

  # this is blocks an input parameter by 'self-disabling', rather than explicitly deleting it
  # it is a bit unorthodox yet expected to be used seldom
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
    descriptor_without_fixed_inputs(super)
  end

  # prevent from showing/submitting fixed inputs in the form
  def descriptor_for_form
    descriptor_without_fixed_inputs(super)
  end

  # show all the params
  def descriptor_for_show_params
    self.invoke_params.merge!(fixed_values) # shows 'fixed' parameters, used would not be able to edit them, so should be save
    super    # standard values
  end

  # validation step - the original boutiques with combined invocation, for the greatest accuracy
  # note, error messages might involve fixed variables
  def after_form
    self.invoke_params.merge!(fixed_values) # put back fixed values into invocation, if needed
    super    # Performs standard processing
  end

end
