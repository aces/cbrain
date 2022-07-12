
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
#             "mem_": "4G",
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

  # deletes fixed inputs listed in the custom 'integrator_modules'
  # no input or values dependencies for fixed variables are supported
  def delete_fixed_inputs(descriptor)
    old_descriptor = descriptor.dup
    #skipped parameters that's unset

    invocation = descriptor.custom_module_info('BoutiquesInputValueFixer')

    # inputs which are deleted by assign null (or, for flags, null-like values)
    skipped = invocation.keys.select do |i_id|

      input = descriptor.input_by_id(i_id)
      value = invocation[i_id]
      value.nil? || input.type == 'Flag' && (value               == 0       || # flag inputs
                                             value.to_s.downcase == 'no'    || # can be skipped by null-like values
                                             value               == [nil]   || # but for other types
                                             value               == '0'     || # to skip a parameter from command line
                                             value.to_s.downcase == 'null'  || # only use
                                             value.to_s.downcase == 'false' || # null
                                             value.blank?
                                             )
    end

    descriptor.inputs = descriptor.inputs.select { |i| ! invocation.key?(i.id)} # filter inputs

    descriptor.groups.each do |g| # filter groups

      members = g.members - invocation.keys
      # deletes a mutualy exclusive group if one element fixed
      if g.mutually_exclusive && members.length != g.members.length
        if (invocation.keys & g.members - skipped).present?
           g.mutually_exclusive == false
           members = nil
        end
      end

      # removes one is required flag if one element fixed
      if g.one_is_required && members.length != g.members.length
        if (invocation.keys & g.members - skipped).present?
          g.one_is_required == false
        end
      end

      # removes one is required flag if one element fixed
      if g.all_or_none && members.length != g.members.length
        if (g.members & skipped).present?
          g.all_or_none == false
        elsif (invocation.keys & g.members - skipped).present? # if one is set, rest should be to
          g.members.each do |iid|
            input = descriptor.input_by_id(iid)
            input.optional = false
          end

        end
      end

      # I suspect that at the moment CBRAIN only fully comfortable
      # with at most one quantifier flag per group
      # and in mutually exclusive
      # (non-overlapping groups), if not more can be done

      g.members = members.presence

      # todo propagate dependencies (it's easier to add internal 'hidden' attribute to inputs)
      # or maybe just delete dependencies

    end
    descriptor.groups = descriptor.groups.compact
    descriptor
  end

  # adjust descriptor to allow check # of supplied files
  def descriptor_before_form #:nodoc:
    descriptor = self.super.dup
    delete_fixed_inputs(descriptor)
  end

  # not show user fixed inputs
  def descriptor_for_form
    descriptor = super.dup
    invocation = descriptor.custom_module_info('BoutiquesInputValueFixer')
    self.invoke_params.merge!(invocation)
    delete_fixed_inputs(descriptor)
  end

  def descriptor_for_show_params
    descriptor = super.dup
    invocation = descriptor.custom_module_info('BoutiquesInputValueFixer')
    self.invoke_params.merge!(invocation)
    delete_fixed_inputs(descriptor)
  end

  require 'pry'
  # validation
  # todo descriptor trimming might needed to hide from executed
  def after_form #:nodoc:
    #binding.pry
    descriptor = self.descriptor_for_after_form
    invocation = descriptor.custom_module_info('BoutiquesInputValueFixer')

    self.invoke_params.merge!(invocation)
    # delete_fixed(descriptor) no idea is needed
    super
  end

  # prepare fixed userfiles
  def setup
    descriptor = self.descriptor_for_setup
    invocation = descriptor.custom_module_info('BoutiquesInputValueFixer')
    self.invoke_params.merge!(invocation)
    super
  end

  # todo delete, is it really needed? maybe to restart on cluster
  # This method overrides the one in BoutiquesClusterTask
  # It adjusts task's invocation
  def cluster_commands
    descriptor = self.descriptor_for_cluster_commands
    invocation = descriptor.custom_module_info('BoutiquesInputValueFixer')
    self.invoke_params.merge!(invocation) # todo, maybe not needed, already done at setup
    super
  end

  # restart postprocessing
  def save_results
    descriptor = self.descriptor_for_save_results
    invocation = descriptor.custom_module_info('BoutiquesInputValueFixer')
    self.invoke_params.merge!(invocation) # todo, maybe not needed, already done at setup
    # Performs standard processing
    super
  end

end
