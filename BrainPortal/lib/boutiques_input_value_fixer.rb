
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

    descriptor_dup = descriptor.deep_dup
    skipped = invocation.keys.select do |i_id|
      begin
        input = descriptor_dup.input_by_id(i_id)
      rescue CbrainError # might be already deleted
        next
      end
      value = invocation[i_id]
      value.nil? || (input.type == 'Flag') &&  (value.presence.to_s.strip =~ /no|0|nil|none|null|false/i || value.blank?)

    end

    descriptor_dup.groups.each do |g| # filter groups
      members = g.members - invocation.keys
      # delete a mutualy exclusive group if its member(s) fixed to a value(s)
      if g.mutually_exclusive && members.length != g.members.length
        if (invocation.keys & g.members - skipped).present?
           g.mutually_exclusive == false
           members = nil
        end
      end

      # removes one is required flag if one element fixed  --use-min-mem vs --mem-mb
      if g.one_is_required && members.length != g.members.length
        if (invocation.keys & g.members - skipped).present?
          g.one_is_required == false
        end
      end

      # removes one is required flag if one element fixed, e.g.
      if g.all_or_none && members.length != g.members.length
        if (g.members & skipped).present?
          g.all_or_none == false
          # todo delete all member inputs
        elsif (invocation.keys & g.members - skipped).present? # if one is set, rest should be to
          g.members.each do |i_id|
            begin
              input = descriptor.input_by_id(i_id)
            rescue CbrainError  # if descriptor was already processed
              next
            end
            input.optional = false
          end
        end
      end

      # I suspect that at the moment CBRAIN only fully comfortable
      # with at most one quantifier flag per group
      # and in mutually exclusive (i.e. non-overlapping) groups.
      # if not, perhaps, more can be done

      g.members = members.presence

      # todo propagate dependencies described with input or value disables, enalbes and requires
      # (it's easier to add internal 'hidden' attribute to inputs in the main codebase)
      # or maybe just delete dependencies or maybe just check that fixed vars are not involved
      # in dependecier

    end
    descriptor_dup.groups = descriptor_dup.groups.compact

    # delete fixed inputs
    descriptor_dup.inputs = descriptor_dup.inputs.select { |i| ! invocation.key?(i.id)} # filter out fixed inputs

    descriptor_dup
  end

  # adjust descriptor to allow check # of supplied files
  def descriptor_for_before_form
    delete_fixed_inputs(super)
  end

  # not show user fixed inputs
  def descriptor_for_form
    self.invoke_params.merge!(invocation)
    delete_fixed_inputs(super)
  end

  def descriptor_for_show_params
    self.invoke_params.merge!(invocation)
    super    # standard values
  end

  # validation
  def after_form
    self.invoke_params.merge!(invocation)
    # delete_fixed(descriptor) no idea is needed
    super    # Performs standard processing
  end

  # prepare userfiles
  def setup
    self.invoke_params.merge!(invocation)
    super    # Performs standard processing
  end

  # re-start on cluster
  # This method overrides the one in BoutiquesClusterTask
  # It adjusts task's invocation
  def cluster_commands
    self.invoke_params.merge!(invocation)
    super    # Performs standard processing
  end

  # for restart postprocessing
  def save_results
    self.invoke_params.merge!(invocation)
    super     # Performs standard processing
  end

end
