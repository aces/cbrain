
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

  require 'pry'

  # the hash of param values to be fixed or be ommited ()  #
  def invocation
    invocation = self.boutiques_descriptor.custom_module_info('BoutiquesInputValueFixer')
    cb_error "module BoutiquesInputValueFixer requires a hash" unless invocation.is_a? Hash
    invocation
  end

  # deletes fixed inputs listed in the custom 'integrator_modules'
  # no input or values dependencies for fixed variables are supported
  def delete_fixed_inputs(descriptor)

    # input parameters are marked by null values will be excluded from the command line
    # the major use case are Flags, but also may be useful to address params with 'default' (
    # or, for flags, null-like values)

    descriptor_dup = descriptor.dup
    skipped = invocation.keys.select do |i_id|
      begin
        input = descriptor_dup.input_by_id(i_id)
      rescue CbrainError # might be already deleted
        next
      end
      value = invocation[i_id]
      value.nil? || (input.type == 'Flag') &&  (value.presence.to_s.strip =~ /no|0|nil|none|null|false/i || value.blank?)

    end



    descriptor_dup.groups.each do |g| # filter groups, relax restriction to anable form submission
      members = g.members - invocation.keys
      # disable a mutualy exclusive group if its param assigned fixed value by this modifier
      # if one simply deletes the fixed param,
      if g.mutually_exclusive && members.length != g.members.length # params can be mutually exclusive e.g. --use-min-mem vs --mem-mb
        if (invocation.keys & g.members - skipped).present? # at least some group members are actually assigned vals rather than deleted
           if members.length == 1
             g.mutually_exclusive = false # drop the restriction, has no point for one element
             # todo add pairwise requires and disables to effectively disable all
           else # when more than one member
             g.all_or_none = true # adding all-or-none will block task submission.
           end
           # a better solution is to delete rest of group params completely
           # a bit more complex though and might result in recursive code or nested loops
        end
      end

      # presently one-is-required is checked only statically, no GUI support
      # removes one-is-required flag if one element fixed
      # if g.one_is_required && members.length != g.members.length
      #   if (invocation.keys & g.members - skipped).present?
      #     g.one_is_required == false
      #   end
      # end

      # all-or-none is not reflected in dynamic gui, uncomment once fixed
      #
      # removes  'one-is-required' or disables group when one or more element fixed, e.g.
      # if g.all_or_none && members.length != g.members.length
      #   # if (g.members & skipped).present?
      #   #   # todo delete all member inputs, or disable by injecting pairwise required/disable dependencie
      #   # end
      #   if (invocation.keys & g.members - skipped).present? # if one is set, rest should be to
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

      # I suspect that at the moment CBRAIN only fully comfortable
      # with at most one quantifier flag per group
      # and in mutually exclusive (i.e. non-overlapping) groups.
      # if not, perhaps, more can be done
      g.members = members
    end
    descriptor_dup.groups = descriptor_dup.groups.select {|g| g.members.present?} # delete empty group

    # delete fixed inputs
    descriptor_dup.inputs = descriptor_dup.inputs.select { |i| ! invocation.key?(i.id)} # filter out fixed inputs

    descriptor_dup
  end

  # adjust descriptor to allow check # of supplied files
  def descriptor_for_before_form
    
    delete_fixed_inputs(super)
  end

  # prevent from showing/submitting fixed inputs in the form
  def descriptor_for_form
    # self.invoke_params.except!(*invocation.keys) # do not use fixed params value in the form
    delete_fixed_inputs(super)
  end

  def descriptor_for_show_params # show all the params
    
    self.invoke_params.merge!(invocation) # show hidden parameters, used would not be able to edit them, so should be save
    super    # standard values
  end

  def after_form # validation step - the original boutiques with combined invocation, for the greatest accuracy
    # note, error messages might involve fixed variables
    self.invoke_params.merge!(invocation) # put back fixed values into invocation, if needed
    super    # Performs standard processing
  end

  # assuming the after_form always happens before cluster steps, the fixed values will be available for them


end
