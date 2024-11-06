
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

# This module adds regular expression validations to the values
# of boutiques parameters. The module is configured in the 'custom'
# section of the descriptor, for instance like this:
#
#   "custom": {
#       "cbrain:integrator_modules": {
#           "BoutiquesInputRegexChecker": {
#               "mem":   [ "[1-9]\\d?[mMgG]", "must be specified as 1m or 4g etc" ],
#               "label": [ "\\w+",            "must be an alphanums string" ]
#           }
#       }
#   }
#
# The regular expressions will be matched against the values of the inputs
# specified in the keys (here, 'mem' and 'label'). The regex will automatically
# be anchored with the Ruby regex anchors "\A" and "\z" on each side.
module BoutiquesInputRegexChecker

  # Note: to access the revision info of the module,
  # you need to access the constant directly, the
  # object method revision_info() won't work.
  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:


  def after_form
    err_message = super # Performs standard processing

    # Find the configured info
    descriptor = self.boutiques_descriptor
    checkers   = descriptor.custom_module_info('BoutiquesInputRegexChecker') || {} # the raw struct in the decriptor

    # Run the checks
    checkers.each do |input_id,regex_message|
      regex,message = *regex_message
      message       = "Contains invalid characters" if message.blank?
      input         = descriptor.input_by_id(input_id)
      value         = self.invoke_params[input_id]
      next if value.nil? && input.optional # nothing to check
      check_regex = Regexp.new('\A' + regex + '\z') # anchor it
      next if value.to_s.match?(check_regex)
      self.params_errors.add(input.cb_invoke_name, message)
    end

    err_message
  end

end
