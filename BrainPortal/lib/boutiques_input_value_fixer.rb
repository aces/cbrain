
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

# This module allows one to fix some of input parameters to specific constant values
# The fixed input(s) would no longer be shown to the user in the form.
# The optional inputs assigned null value will be removed
# (do not use with mandatory input parameters)
#
# In the descriptor, the spec would look like:
#
#   "custom": {
#       "cbrain:integrator_modules": {
#           "BoutiquesInputValueFixer": {
#               "n_cpus": 1,
#               "mem": "4G",
#               "optional_custom_query": null,
#               "level": "group"
#           }
#       }
#   }
#
# Our main use case is resource related parameter which seldom participate
# in dependencies and constraints.
# Therefore we remove parameters from the form in a straightforward fashion
# and do not address indirect or transitive dependencies. For instance,
# if say i1-requires->i2-requires->i3 while i2 is deleted, dependency
# of i3 on i1 no longer be reflected in web form UI dynamically
module BoutiquesInputValueFixer

  # Note: to access the revision info of the module,
  # you need to access the constant directly, the
  # object method revision_info() won't work.
  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:


  # the hash of input parameter values to be fixed or, if value is null, to be omitted
  def fixed_values
    self.boutiques_descriptor.custom_module_info('BoutiquesInputValueFixer') || {}
  end

  # deletes fixed inputs listed in the custom 'integrator_modules'
  def descriptor_without_fixed_inputs(descriptor)
    # input parameters are marked by null values will be excluded from the command line
    # other will be given fixed values during execution; neither should appear in web form UI

    fixed_input_ids = fixed_values.keys
    return descriptor if fixed_input_ids.blank? # no config means nothing to do
    descriptor_dup  = descriptor.dup
    fully_removed   = fixed_input_ids.select do |i_id|  # this variables are flagged to be removed rather than assigned value
                                                   # in the spec, so they will be treated slightly different
      input = descriptor_dup.input_by_id(i_id)
      value = fixed_values[i_id]
      value.nil? || (input.type == 'Flag') &&  (value.presence.to_s.strip =~ /0|null|false/i || value.blank?)
    end

    # generally speaking, boutiques input groups can have three different constraints,
    # here we address 1) mutually exclusive constraint, which is the only one present in GUI javascript (the rest are evaluated
    # after submission of the form), 2) 'one is required' constraint that affect the initial rendering of the form
    # ( though IMHO red stars or other indicators to draw user attention should eventually implemented )

    descriptor_dup.groups.each do |g| # filter groups, relax restriction to ensure that form can still be submitted
      members = g.members - fixed_input_ids

      # some actions at least some group members are actually assigned vals rather than deleted
      if (fixed_input_ids & g.members - fully_removed).present? #
        # since one input parameter is already selected permanently (fixed),
        # we can drop one_is_required constraint
        g.one_is_required = false  # as result group's checkbox is unselected in form rendering

        # as one of mutually exclusive parameters is selected by setting a fixed value
        # the rest of group should be disabled, no remaining
        # Whenever deleting all remaining parameters of the group is preferred to disabling
        # boutiques author/admin can modify the list of fixed values accordingly
        block_inputs(descriptor_dup, members) if g.mutually_exclusive
        g.mutually_exclusive = false  # will make form's javascript smaller/faster

        # all-or-none constraint is seldom used, does not affect form itself,
        # and only validated after the form submission
        # and generally presents less pitfalls
        # Therefore, at the moment, 'all or none' constraint is not addressed here

      end
      g.members = members
    end

    # remove empty groups
    descriptor_dup.groups = descriptor_dup.groups.select {|g| g.members.present? }

    # delete fixed inputs
    descriptor_dup.inputs = descriptor_dup.inputs.select { |i| ! fixed_values.key?(i.id) } # filter out fixed inputs

    # straight-forward delete of fixed inputs from dependencies.
    # Indirect and transitive dependencies may be lost for UI
    # but will be validated after form submission
    descriptor_dup.inputs.each do |i|
      i.requires_inputs = i.requires_inputs - fixed_input_ids if i.requires_inputs.present?
      i.disables_inputs = i.disables_inputs - fixed_input_ids if i.disables_inputs.present?
      i.value_requires.each { |v, a| i.value_requires[v] -= fixed_input_ids } if i.value_requires.present?
      i.value_disables.each { |v, a| i.value_disables[v] -= fixed_input_ids } if i.value_disables.present?
    end

    descriptor_dup
  end

  # this blocks an input parameter by 'self-disabling', rather than explicitly deleting it
  # it is a bit unorthodox yet expected to be used seldom
  def block_inputs(descriptor, input_ids)
    input_ids.each do |input_id|
      input = descriptor.input_by_id(input_id) rescue next
      input.disables_inputs ||= []
      input.disables_inputs |= [input_id]
      input.name += " ( unavailable )"
    end
  end

  # adjust descriptor to allow check the number of supplied files
  def descriptor_for_before_form
    descriptor_without_fixed_inputs(super)
  end

  # prevent from showing/submitting fixed inputs in the form
  def descriptor_for_form
    descriptor_without_fixed_inputs(super)
  end

  # show all the params
  def descriptor_for_show_params
    self.invoke_params.merge!(fixed_values) # shows 'fixed' parameters, user would not be able to edit them
    super    # standard values
  end

  # validation step - the original boutiques with combined invocation, for the greatest accuracy
  # note, error messages might involve fixed variables
  def after_form
    self.invoke_params.merge!(fixed_values.compact) # put back fixed values into invocation, if needed
    super    # Performs standard processing
  end

end
