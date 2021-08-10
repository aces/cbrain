
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

class BoutiquesTask < CbrainTask # TODO PortalTask vs ClusterTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def boutiques_descriptor
    self.tool_config.boutiques_descriptor
  end

  def descriptor_for_before_form
    boutiques_descriptor
  end

  def descriptor_for_after_form
    boutiques_descriptor
  end

  # STANDARD PORTAL TASK METHODS

  def self.properties
    {
      :no_submit_button      => false,
      :no_presets            => false,
      :read_only_input_files => false, # TODO this is a class method, no access to descriptor
    }
  end

  def default_launch_args
    descriptor_for_before_form
      .inputs
      .reject { |input|   input.type == 'File' }
      .select { |input| ! input.default_value.nil? }
      .map    { |input| [ input.id, input.default_value ] }
      .to_h
  end

  def before_form
    descriptor        = descriptor_for_before_form

    num_needed_inputs = descriptor.required_file_inputs.size
    num_opt_inputs    = descriptor.optional_file_inputs.size
    num_in_files      = Userfile.where(:id => (self.params[:interface_userfile_ids] || [])).count

    # This is a message describing briefly all file inputs
    input_infos = descriptor.file_inputs
      .map { |i|
        iname     = i['name']
        ioptional = i['optional'] ? '(optional)' : '(required)'
        "#{iname} #{ioptional}\n"
      }.join("")

    if num_in_files < num_needed_inputs || num_in_files > num_needed_inputs+num_opt_inputs
      message = "This task requires #{num_needed_inputs} mandatory file(s) and #{num_opt_inputs} optional file(s)\n" +
        input_infos
      cb_error message
    end

    #return "Warning: you selected more files than this task requires, so you won't be able to assign them all." if
    #  num_needed_inputs > num_needed_inputs+num_opt_inputs

    ""
  end

  def after_form
    descriptor = descriptor_for_after_form

    # -------------------------
    # Sanitize parameter values
    # -------------------------

    # Required parameters
    descriptor.required_inputs.each do |input|
      sanitize_param(input)
    end

    # Optional parameters
    descriptor.optional_inputs.each do |input|
      sanitize_param(input) unless isInactive(input)
    end

    # ---------------------------------------------------------------
    # Check that any enum parameters have been given allowable values
    # ---------------------------------------------------------------

    descriptor.inputs.select(&value_choices).each do |input|
      check_enum_param(input) unless isInactive(input)
    end

    # -------------------------------------------------------------------------------
    # Check that number parameters with contraints have been given permissible values
    # -------------------------------------------------------------------------------

    descriptor.inputs.select { |input| input.type == 'Number' }.each do |input|
      check_number_param(input) unless isInactive(input)
    end

    # ----------------------------------------
    # Check that list lengths are not violated
    # ----------------------------------------

    descriptor.list_inputs.each do |input|
      check_list_param(input) unless isInactive(input)
    end

    # ---------------------------------
    # Check dependencies between inputs
    # ---------------------------------

    descriptor.inputs.each do |input|

      # Inputs that want other inputs to NOT BE provided
      (input.disables_inputs || []).each do |dontneed|
        next if isInactive(dontneed)
        dontneedinput = descriptor.input_by_id(dontneed)
        params_errors.add(
          dontneedinput.cb_invoke_name,
          "is disabled by " + input.name
        )
      end

      # Inputs that want other inputs to BE provided
      (input.requires_inputs || []).each do |need|
        next if ! isInactive(need)
        needinput = descriptor.input_by_id(need)
        params_errors.add(
          needinput.cb_invoke_name,
          "is required for " + input.name
        )
      end

    end # check dependencies

    # ---------------------------------
    # Check groups
    # ---------------------------------
    descriptor.groups.each do |group|
      check_mutex_group(group)         if group.mutually_exclusive
      check_oneisrequired_group(group) if group.one_is_required
    end

    xxx

  end # after_form

  # Portal-side utilities

  private

  # Helper function for detecting inactive parameters (or false for flag-type parameters)
  # Note that empty strings are allowed and no parameter types except flags pass booleans
  # The argument 'x' can either be a Input object, or a string for the ID of the input param.
  def isInactive(input)
    key = input.is_a?(BoutiquesDescriptor::Input) ? input.id : input
    invoke_params[key].nil? || (invoke_params[key] == false)
  end

  # Ensure that the +input+ parameter is not null and matches a generic tool
  # parameter type (:file, :numeric, :string or :flag) before converting the
  # parameter's value to the corresponding Ruby type (if appropriate).
  # For example, sanitize_param(someinput) where someinput's name is 'deviation'
  # and someinput's type is 'numeric' would validate that
  # self.params['invoke']['deviation'] is a number and then convert it to a Ruby Float or
  # Integer.
  #
  # If the parameter's value is an array, every value in the array is checked
  # and expected to match +type+.
  #
  # Raises an exception for the input parameter name if the parameter's value
  # is not adequate.
  def sanitize_param(input)

    name = input.id
    type = input.type.downcase.to_s # old code convention from previous integrator

    # Taken userfile names. An error will be raised if two input files have the
    # same name.
    @taken_files ||= Set.new

    # Fetch the parameter and convert to an Enumerable if required
    values = invoke_params[name] rescue nil
    values = [values] unless values.is_a?(Enumerable)

    # Paramspath used for error messages
    invokename = input.cb_invoke_name

    # Validate and convert each value
    values.map! do |value|
      case type
      # Try to convert to integer and then float. Cant? then its not a number.
      when :number
        if (number = Integer(value) rescue Float(value) rescue nil)
          value = number
        elsif value.blank?
          params_errors.add(invokename, ": value missing")
        else
          params_errors.add(invokename, ": not a number (#{value})")
        end

      # Nothing special required for strings, bar for symbols being acceptable strings.
      when :string
        value = value.to_s if value.is_a?(Symbol)
        params_errors.add(invokename, " not a string (#{value})")       unless value.is_a?(String)
        # The following two checks are to prevent cases when
        # a string param is used as a path
        params_errors.add(invokename, " cannot contain newlines")            if value.to_s =~ /[\n\r]/
        params_errors.add(invokename, " cannot start with these characters") if value.to_s =~ /^[\.\/]+/

      # Try to match against various common representation of true and false
      when :flag
        if value.is_a?(String)
          value = true  if value =~ /\A(true|t|yes|y|on|1)\z/i
          value = false if value =~ /\A(false|f|no|n|off|0|)\z/i
        end

        if ! [ true, false ].include?(value)
          params_errors.add(invokename, ": not true or false (#{value})")
        end

      # Make sure the file ID is valid, accessible, not already used and
      # of the correct type.
      when :file
        unless (Integer(value) rescue nil)
          params_errors.add(invokename, ": invalid or missing userfile (ID #{value})")
          next value
        end

        unless (file = Userfile.find_accessible_by_user(value, self.user, :access_requested => file_access_symbol()))
          params_errors.add(invokename, ": cannot find userfile (ID #{value})")
          next value
        end

        if @taken_files.include?(file.name)
          params_errors.add(invokename, ": file name already in use (#{file.name})")
        else
          @taken_files.add(file.name)
        end

      end

      value
    end

    # Store the value back
    invoke_params[name] = values.first unless invoke_params[name].is_a?(Enumerable)
  end

  def check_enum_param(input)
    value = invoke_params[input.id]
    string_values  = Array(value).map(&:to_s)
    allowed_values = input.value_choices.map(&:to_s)
    next if (string_values - allowed_values).empty? # I hope that comparing the sets as strings is OK
    params_errors.add(input.cb_invoke_name, "was not given an acceptable value")
  end

  def check_number_param(input)
    value  = invoke_params[input.id]
    values = Array(value).map(&:to_f)

    if input.minimum
      clusive = input.exclusive_minimum ? "exclusive" : "inclusive"
      ok = values.all? { |v| v.to_f >  input.minimum.to_f } if clusive == 'exclusive'
      ok = values.all? { |v| v.to_f >= input.minimum.to_f } if clusive == 'inclusive'
      if ! ok
        params_errors.add(input.cb_invoke_name, "violates #{clusive} minimum value #{input.minimum}")
      end
    end

    if input.maximum
      clusive = input.exclusive_maximum ? "exclusive" : "inclusive"
      ok = values.all? { |v| v.to_f <  input.maximum.to_f } if clusive == 'exclusive'
      ok = values.all? { |v| v.to_f <= input.maximum.to_f } if clusive == 'inclusive'
      if ! ok
        params_errors.add(input.cb_invoke_name, "violates #{clusive} maximum value #{input.minimum}")
      end
    end

    if input.integer
      ok = values.all? { |v| Integer(v.to_s) rescue false }
      if ! ok
        params_errors.add(input.cb_invoke_name, "must be an integer")
      end
    end
  end

  def check_list_param(input)
    values = invoke_params[input.id]
    if ! values.is_a?(Enumerable)
      params_errors.add(input.cb_invoke_name, "is not a list?!?") # internal error?
      next
    end
    min   = input.min_list_entries # can be nil
    max   = input.max_list_entries # can be nil
    if min && values.size < min
      params_errors.add(input.cb_invoke_name, "must contain at least #{min} values")
    end
    if max && values.size > max
      params_errors.add(input.cb_invoke_name, "must contain no more than #{max} values")
    end
  end

  def check_mutex_group(group, descriptor = descriptor_for_after_form)
    members = group.members
    are_set = members.select { |inputid| ! isInactive(inputid) }
    return if are_set.size <= 1
    are_set.each do |inputid|
      params_errors.add(group.name, " can have at most one parameter set")
      #input = descriptor.input_by_id(inputid)
      #add error for input too?
    end
  end

  def check_oneisrequired_group(group, descriptor = descriptor_for_after_form)
    members = group.members
    are_set = members.select { |inputid| ! isInactive(inputid) }
    return if are_set.size > 0
    params_errors.add(group.name, " need at least one parameter set")
  end

xxx

  # MAYBE IN COMMON

  public

  def invoke_params
    self.params['invoke'] ||= {}
  end

  # This determines if the task expects to only read its input files,
  # or modify them, and return respectively :read or :write (the default).
  # The symbol can be passed to methods such as Userfile.find_accessible_by_user().
  # Depending on the value, more or less files are allowed to be processed.
  # When the value is :read, it means we only need file for input and not
  # for output.
  def file_access_symbol
    @_file_access ||= (self.class.properties[:readonly_input_files].present? || self.tool_config.try(:inputs_readonly) ? :read : :write)
  end

end
