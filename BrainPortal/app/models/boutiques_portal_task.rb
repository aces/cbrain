
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

class BoutiquesPortalTask < PortalTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # This method returns the BoutiquesDescriptor
  # directly associated with the ToolConfig for the task
  def boutiques_descriptor
    self.tool_config.boutiques_descriptor ||
    self.find_compatible_placeholder_descriptor ||   # Workaround #1 for misconfigured portal
    self.generate_placeholder_descriptor             # Workaround #2 for misconfigured portal
  end

  # This method returns the same descriptor as
  # boutiques_descriptor(), by default, but can be overriden
  # by subclasses to change the behavior of what happens
  # in the before_form() method.
  def descriptor_for_before_form
    self.boutiques_descriptor
  end

  # This method returns the same descriptor as
  # boutiques_descriptor(), by default, but can be overriden
  # by subclasses to change the behavior of what happens
  # in the after_form() method.
  def descriptor_for_after_form
    self.boutiques_descriptor
  end

  # This method returns the same descriptor as
  # boutiques_descriptor(), by default, but can be overriden
  # by subclasses to change the behavior of what happens
  # in the final_task_list() method.
  def descriptor_for_final_task_list
    self.boutiques_descriptor
  end

  # This method returns the same descriptor as
  # boutiques_descriptor(), by default, but can be overriden
  # by subclasses to change the behavior of what happens
  # when generating the task's parameter page.
  def descriptor_for_form
    self.boutiques_descriptor
  end

  # This method returns the same descriptor as
  # boutiques_descriptor(), by default, but can be overriden
  # by subclasses to change the behavior of what happens
  # when generating the task's "show" page.
  def descriptor_for_show_params
    self.boutiques_descriptor
  end



  ##############################
  # STANDARD PORTAL TASK METHODS
  ##############################

  def self.properties #:nodoc:
    {
      :no_submit_button      => false,
      :no_presets            => false,
      :read_only_input_files => false, # TODO this is a class method, no access to descriptor
    }
  end

  def default_launch_args #:nodoc:
    invoke_struct = self.descriptor_for_before_form
      .inputs
      .reject { |input|   input.type == 'File' }
      .select { |input| ! input.default_value.nil? }
      .map    { |input| [ input.id, input.default_value ] }
      .to_h
    {
      :invoke => invoke_struct,
    }.with_indifferent_access
  end

  def before_form
    descriptor        = self.descriptor_for_before_form

    num_needed_inputs = descriptor.required_file_inputs.size
    num_opt_inputs    = descriptor.optional_file_inputs.size
    num_in_files      = Userfile.where(:id => (self.params[:interface_userfile_ids] || [])).count

    # This is a message describing briefly all file inputs
    input_infos = descriptor.file_inputs
      .map { |i|
        iname     = i.name
        ioptional = i.optional ? '(optional)' : '(required)'
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
    descriptor = self.descriptor_for_after_form

    # Record pretty params names in class
    self.class.add_pretty_params_names(descriptor.inputs || [])

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
    # Check that there are no spurious parameters
    # ---------------------------------------------------------------
    expected = descriptor.inputs.map(&:id)
    notexp   = invoke_params.keys - expected
    self.errors.add(:base, "We received some unexpected parameters: #{notexp.join(", ")}") if notexp.present?

    # ---------------------------------------------------------------
    # Check that any enum parameters have been given allowable values
    # ---------------------------------------------------------------

    descriptor.inputs.select(&:value_choices).each do |input|
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
      next if input.type == 'File' # these are special
      check_list_param(input) unless isInactive(input)
    end

    # ---------------------------------
    # Check dependencies between inputs
    # ---------------------------------

    descriptor.inputs.each do |input|

      next if isInactive(input)

      # Inputs that want other inputs to NOT BE provided
      (input.disables_inputs || []).each do |dontneed| # loop on IDs
        dontneedinput = descriptor.input_by_id(dontneed)
        next if isInactive(dontneedinput)
        params_errors.add(
          dontneedinput.cb_invoke_name,
          "is disabled by " + input.name
        )
      end

      # Inputs that want other inputs to BE provided
      (input.requires_inputs || []).each do |need| # loop on IDs
        needinput = descriptor.input_by_id(need)
        next if ! isInactive(needinput)
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
      check_allornone_group(group)     if group.all_or_none
    end

    # ------------------------------------------------
    # Check the content of all CbrainFileLists (cbcsv)
    # ------------------------------------------------
    # Get all the input cbcsv files
    cbcsvs  = self.cbcsv_files # [ [input, cbcsv_userfile], [input, cbcsv_userfile], ... ]
    numRows = nil # Keep track of number of files per cbcsv
    # Validate each cbcsv (all columns match per row, user has access to the file)
    for input, cbcsv in cbcsvs
      invokename = input.cb_invoke_name
      # Error if the type is wrong
      next unless checkCbcsvType(cbcsv, invokename)
      # Ensure user access is correct
      next unless ascertainCbcsvUserAccess(cbcsv, invokename)
      # If the number of rows does not match, error
      # We need only check this for inputs that are not "list".
      if ! input.list
        currNumRows   = (cbcsv.ordered_raw_ids || []).length
        numRows     ||= currNumRows
        if currNumRows != numRows
          params_errors.add(invokename, " does not have the same number of files (#{currNumRows}) as in other present cbcsvs (#{numRows})")
          next
        end
      end
      # Validate the other file columns
      validateCols(cbcsv, invokename)
    end

    "" # No special message for user
  end # after_form

  def self.pretty_params_names
    @_pretty_params_names ||= {}
    super.merge @_pretty_params_names
  end

  def self.add_pretty_params_names(inputs)
    @_pretty_params_names ||= {}
    inputs.each do |input|
      invokename = input.cb_invoke_name
      pretty     = input.name
      @_pretty_params_names[invokename] = pretty
    end
    @_pretty_params_names
  end

  # Final set of tasks to be launched based on this task's parameters.
  def final_task_list #:nodoc:
    descriptor = self.descriptor_for_final_task_list

    self.addlog(Revision_info.format("%f rev. %s %a %d"))
    self.addlog(self.boutiques_descriptor.file_revision_info.format("%f rev. %s %a %d"))

    # Add author(s) information
    authors = Array(descriptor.custom['cbrain:author'])
    authors = authors.empty? ? "No CBRAIN author information" :
                                authors.join(", ")
    self.addlog("CBRAIN Author(s): #{authors}")

    # Add information about Boutiques module
    boutiques_module_information().each do |log_info|
       self.addlog(log_info)
    end

    valid_input_keys = descriptor.inputs.map(&:id)

    # --------------------------------------
    # Special case where there is a single file input
    # We generate one task per selected file, PLUS
    # one task for each file inside any CbrainFileLists
    # in that set too. So if the user selects:
    #
    #   (TextFile), (CbCsv with 3 files), (TextFile), (CbCsv with 2 files)
    #
    # then we will generate 7 tasks in total.
    # --------------------------------------
    if descriptor.file_inputs.size == 1
      input = descriptor.file_inputs.first

      fillTask = lambda do |userfile,tsk,extra_params=nil|
        tsk.params[:interface_userfile_ids] |= [ userfile.id.to_s ]
        tsk.invoke_params[input.id]          = userfile.id
        tsk.sanitize_param(input)
        tsk.description = "#{input.id}: #{userfile.name}\n#{tsk.description}".strip
        tsk.invoke_params.merge!(extra_params.slice(*valid_input_keys)) if extra_params
        tsk.description.strip!
        tsk
      end

      original_userfiles_ids = self.params[:interface_userfile_ids].dup
      self.params[:interface_userfile_ids] = [] # zap it; we'll re-introduce each userfile.id as needed
      tasklist = original_userfiles_ids.map do |userfile_id|
        if CbrainFileList.find_by(:id => userfile_id)
          f = CbrainFileList.find_accessible_by_user( userfile_id, self.user, :access_requested => :read )
        else
          f = Userfile.find_accessible_by_user( userfile_id, self.user, :access_requested => :read )
        end

        # One task for that file
        if (! f.is_a?( CbrainFileList ) || input.list) # in case of a list input, we *do* assign it the CbFileList
          task = self.dup
          fillTask.( f, task )
        else # One task per userfile in the CbrainFileList
          ufiles               = f.userfiles_accessible_by_user!( self.user, nil, nil, file_access_symbol() )
          ordered_extra_params = f.is_a?(ExtendedCbrainFileList) ? f.ordered_params : []

          # Fill subtasks array
          subtasks = []
          ufiles.each_with_index do |u, index|
            next if u.nil?
            subtasks << fillTask.( u, self.dup, ordered_extra_params[index])
          end

          subtasks # an array of tasks
        end
      end

      return tasklist.flatten
    end # When only one file input

    # --------------------------------------
    # General case: more than one file input
    # In that case we expand CBCsv
    # --------------------------------------

    # Grab all the cbcsv input files
    cbcsvs = self.cbcsv_files(descriptor) # [ [input, cbcsv_userfile], [input, cbcsv_userfile], ... ]
    cbcsvs.reject! { |pair| pair[0].list } # ignore file inputs with list=true; they just get the CBCSV directly

    # Default case: just return self as a single task
    # if there are no cbcsvs involved
    if cbcsvs.empty?
      return [ self ] # just one task
    end

    # Array with the actual userfiles corresponding to the cbcsv
    mapCbcsvToUserfiles = cbcsvs.map { |f| f[1].ordered_raw_ids.map { |i| (i==0) ? nil : i } }
    # Array with the actual extra json_params corresponding to the cbcsv
    mapCbcsvToParams    =  cbcsvs.map do |f|
                             cbcsv = f[1]
                             cbcsv.is_a?(ExtendedCbrainFileList) ?
                               cbcsv.ordered_params : []
                           end

    # Task list to fill and total number of tasks to output
    tasklist         = []
    nTasks           = mapCbcsvToUserfiles[0].length

    # Iterate over each task that needs to be generated
    for i in 0..(nTasks - 1)
      # Clone this task
      currTask = self.dup
      # Replace each cbcsv with an entry
      cbcsvs.map { |f| f[0] }.each_with_index do |cinput,j|
        currId = mapCbcsvToUserfiles[j][i]
        #currTask.params[:interface_userfile_ids] << mapCbcsvToUserfiles unless currId.nil?
        currTask.invoke_params[cinput.id] = currId # If id = 0 or nil, currId = nil
        currTask.invoke_params.delete(cinput.id) if currId.nil?
        extra_params_from_Cbcsv     = mapCbcsvToParams[j][i] || {}
        currTask.invoke_params.merge!(extra_params_from_Cbcsv.slice(*valid_input_keys))
      end
      # Add the new task to our tasklist
      tasklist << currTask
    end

    return tasklist
  end

  # Task parameters to leave untouched by the edit task mechanism. Usually
  # for parameters added in after_form or final_task_list, as those wouldn't
  # be present on the form and thus lost when the task is edited.
  def untouchable_params_attributes #:nodoc:
    descriptor  = boutiques_descriptor
    outputs     = descriptor.output_files || []

    # Output parameters will be present after the task has run and need to be
    # preserved.
    output_syms = outputs.map { |output| "_cbrain_output_#{output.id}".to_sym }
    super.merge(
      output_syms.map { |sym| [ sym, true] }.to_h
    )
  end



  ################################
  # Portal-side utilities
  ################################

  # Returns all the cbcsv files present (i.e. set by the user as inputs), as tuples (input, Userfile)
  def cbcsv_files(descriptor = self.descriptor_for_after_form)
    descriptor.file_inputs.map do |input|
        next if isInactive(input)
        userfile_id = invoke_params[input.id]
        next if userfile_id.blank?
        userfile = Userfile.find_accessible_by_user(userfile_id, self.user, :access_requested => :read)
        next unless ( userfile.is_a?(CbrainFileList) || (userfile.suggested_file_type || Object) <= CbrainFileList )
        [ input, userfile ]
    end.compact
  end

  # Helper function for detecting inactive parameters (or false for flag-type parameters)
  # Note that empty strings are allowed and no parameter types except flags pass booleans
  # The argument +input+ must be a Input object.
  def isInactive(input)
    type = input.type
    val  = self.invoke_params[input.id]
    (
      val.nil? || # most of the time, the interface sends NO value at all, which is what we prefer
      (type == 'Flag' && val == "0")   || # checkboxes send their values as strings 0 and 1,
      (type == 'Flag' && val == false)    # but normally they are transformed into bool in sanitize_param()
    )
  end

  # Checks that the cbcsv is the correct type
  # Current implementation will output an error here if a person uploads a cbcsv
  # but forgets to change its type to cbcsv. I.e. we assume it is an error to use
  # a .cbcsv for anything except generating a CbrainFileList object.
  def checkCbcsvType(f,id)
    isCbcsv = f.is_a?(CbrainFileList)
    msg = " is not of type CbrainFileList (file #{f.name})! Please convert it with the file manager. (Type: #{f.class})"
    params_errors.add(id, msg) unless isCbcsv
    isCbcsv
  end

  # Check that the user can access the cbcsv files
  def ascertainCbcsvUserAccess(f,id)
    # Error message when a file cannot be found (e.g. non-existent id)
    msg1 = lambda { |i| " - unable to find file with id #{i} in cbcsv #{f.name}. Ensure you own all the given files." }
    # Error message when an exception is thrown
    msg2 = lambda { |e| " cbcsv accessibility error in #{f.name}! Possibly due to cbcsv malformation. (Received error: #{e.inspect})" }
    errFlag = true # Whether the error checking found a problem
    begin # Check that the user has access to all of the files in the cbcsv
      f.sync_to_cache # We need the content of the cbcsv
      f.userfiles_accessible_by_user!(self.user, nil, nil, file_access_symbol()) # side effect: cache entries within f
      for i in f.ordered_raw_ids.select{ |r| (! r.nil?) && (r.to_s != '0') }
        accessible = Userfile.find_accessible_by_user( i, self.user, :access_requested => file_access_symbol() ) rescue nil
        params_errors.add( id, msg1.(i) ) unless accessible
        errFlag = false unless accessible
      end
    rescue => e # Catches errors from userfiles_accessible_by_user
      params_errors.add( id, msg2.(e) )
      errFlag = false
    end
    errFlag
  end

  # Check that the validation of the other columns of a CBCSV goes through
  def validateCols(cbcsv,id)
    # Error-check the remainder of the file with max_errors = 1 and non-strict (so zero rows can have anything in them)
    allGood   = cbcsv.validate_extra_attributes(self.user, 1, false, file_access_symbol()) rescue false # returns true if no errors
    allGood ||= cbcsv.errors # If there were errors, we want to look at them
    params_errors.add(id, "has attributes (in cbcsv: #{cbcsv.name}) that are invalid (Received error: #{allGood.messages})") unless (allGood == true)
    allGood
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
    type = input.type.downcase.to_sym # old code convention from previous integrator

    # For strings, we support a special list of parameters
    # that can be empty strings.
    descriptor = self.descriptor_for_after_form
    empty_string_allowed = Array(descriptor.custom['cbrain:allow_empty_strings']).include?(name)

    # Taken userfile names. An error will be raised if two input files have the
    # same name.
    @taken_files ||= Set.new

    # Fetch the parameter and convert to an Enumerable if required
    values = invoke_params[name]
    values = [values] unless values.is_a?(Enumerable)

    # Paramspath used for error messages
    invokename = input.cb_invoke_name

    # Validate and convert each value
    values.map! do |value|
      case type
      # Try to convert to integer and then float. Cant? then its not a number.
      when :number
        if value.blank?
          params_errors.add(invokename, ": value missing")
        elsif (number = Integer(value) rescue Float(value) rescue nil)
          value = number
        else
          params_errors.add(invokename, ": not a number (#{value})")
        end

      # Nothing special required for strings, bar for symbols being acceptable strings.
      when :string
        value = value.to_s if value.is_a?(Symbol)
        params_errors.add(invokename, " not a string (#{value})")      unless value.is_a?(String)
        params_errors.add(invokename, " is blank")                         if value.blank? && !empty_string_allowed
        # The following two checks are to prevent cases when
        # a string param is used as a path
        params_errors.add(invokename, " cannot contain newlines")          if value.to_s =~ /[\n\r]/
        params_errors.add(invokename, " cannot start with this character") if value.to_s =~ /^[\.\/]+/
        params_errors.add(invokename, " cannot move up dirs")              if value.to_s.include? "/../"

      # Try to match against various common representation of true and false
      when :flag
        value = true  if value.to_s =~ /\A(true|t|yes|y|on|1)\z/i
        value = false if value.to_s =~ /\A(false|f|no|n|off|0|)\z/i

        if ! [ true, false ].include?(value)
          params_errors.add(invokename, ": not true or false (#{value})")
        end

      # Make sure the file ID is valid, accessible, not already used and
      # of the correct type.
      when :file
        unless (Integer(value) rescue nil)
          params_errors.add(invokename, ": invalid or missing userfile")
          next nil # remove bad value
        end

        file = Userfile.find_accessible_by_user(value, self.user, :access_requested => :read) rescue nil
        unless file
          params_errors.add(invokename, ": cannot find userfile (ID #{value})")
          next nil # remove bad value
        end

        if @taken_files.include?(file.id)
          params_errors.add(invokename, ": file name already in use (#{file.name})")
        else
          @taken_files.add(file.id)
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
    return if (string_values - allowed_values).empty? # I hope that comparing the sets as strings is OK
    params_errors.add(input.cb_invoke_name, "was not given an acceptable value")
  end

  def check_number_param(input)
    value  = invoke_params[input.id]
    values = Array(value)

    if input.integer
      ok = values.all? { |v| Integer(v.to_s) rescue false }
      if ! ok
        params_errors.add(input.cb_invoke_name, "must be specified as integer")
        return # no need to check anything else
      end
    end

    # For all other checks we compare as floats
    values = values.map(&:to_f)

    if input.minimum
      clusive = input.exclusive_minimum ? "exclusive" : "inclusive"
      ok = values.all? { |v| v >  input.minimum.to_f } if clusive == 'exclusive'
      ok = values.all? { |v| v >= input.minimum.to_f } if clusive == 'inclusive'
      if ! ok
        params_errors.add(input.cb_invoke_name, "violates #{clusive} minimum value #{input.minimum}")
      end
    end

    if input.maximum
      clusive = input.exclusive_maximum ? "exclusive" : "inclusive"
      ok = values.all? { |v| v <  input.maximum.to_f } if clusive == 'exclusive'
      ok = values.all? { |v| v <= input.maximum.to_f } if clusive == 'inclusive'
      if ! ok
        params_errors.add(input.cb_invoke_name, "violates #{clusive} maximum value #{input.minimum}")
      end
    end

  end

  def check_list_param(input)
    values = invoke_params[input.id]
    if ! values.is_a?(Enumerable)
      params_errors.add(input.cb_invoke_name, "is not a list?!?") # internal error?
      return
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

  def check_mutex_group(group, descriptor = self.descriptor_for_after_form)
    members = group.members
    are_set = members.select { |inputid| ! isInactive(descriptor.input_by_id inputid) }
    return if are_set.size <= 1
    are_set.each do |inputid|
      params_errors.add(group.name, " can have at most one parameter set")
      #input = descriptor.input_by_id(inputid)
      #add error for input too?
    end
  end

  def check_oneisrequired_group(group, descriptor = self.descriptor_for_after_form)
    members = group.members
    are_set = members.select { |inputid| ! isInactive(descriptor.input_by_id inputid) }
    return if are_set.size > 0
    params_errors.add(group.name, " need at least one parameter set")
  end

  def check_allornone_group(group, descriptor = self.descriptor_for_after_form)
    members = group.members
    num_unset = members.count { |inputid| isInactive(descriptor.input_by_id inputid) }
    return if num_unset == 0 || num_unset == members.size # all, or none
    params_errors.add(group.name, " need either all the parameters set or neither")
  end

  # MAYBE IN COMMON

  def invoke_params
    self.params[:invoke] ||= {}
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

  # In the case of a misconfiguration of the portal, or if the file for
  # the Boutiques descriptor has disappeared, this method will look at
  # other ToolConfigs associated with the tool of the task and try find
  # a replacement descriptor. It's not garanteed that this descriptor
  # is compatible with the params of the task but it's probably good
  # enough to show the task to the user.
  #
  # The task object itself will get a permanent ActiveRecord
  # error added to its base to prevent any saving/editing/launching.
  #
  # See also the method generate_placeholder_descriptor which, in case
  # we can't find a descriptor here, is called to create a fake
  # descriptor out of thin air.
  #
  # Known limitations: if the original task was integrated with
  # special modules that have custom entries that are different
  # than the ones in the found descriptor, the callback methods
  # setup(), before_form() etc might crash.
  def find_compatible_placeholder_descriptor

    # Build a list of tool configs to scan
    tool_configs       = self.tool.tool_configs.order("created_at desc").to_a

    # Find the most recently created one (hopefully, backwards compatible)
    compat_tool_config = tool_configs.detect { |tc| tc.boutiques_descriptor } # first one is the one we use
    return nil if ! compat_tool_config

    # Add persistent errors, to make sure the task cannot be touched.
    if self.errors.blank?
      cur_version = self.tool_config.version_name
      alt_version = compat_tool_config.version_name
      self.errors.add(:base, "The Boutiques Descriptor for version '#{cur_version}' of this task has disappeared. This is a configuration error, contact the administrators.")
      self.errors.add(:base, "A descriptor from another version ('#{alt_version}') is currently in use to allow you to view the parameters.")
      self.errors.add(:unsavable, ": The parameters for this task cannot be modified.") # this special error prevents the save button from working
    end

    compat_tool_config.boutiques_descriptor
  end

  # In the case of a misconfiguration of the portal, or if the file for
  # the Boutiques descriptor has disappeared, this method will look at the
  # current params of the task and create out of thin air a new fake
  # descriptor for it. This allows the user to (at least) view the task
  # in the interface.
  #
  # The task object itself will get a permanent ActiveRecord
  # error added to its base to prevent any saving/editing/launching.
  #
  # Known limitations: if the original task was integrated with
  # special modules that require custom entries in the descriptor,
  # the callback methods setup(), before_form() etc might crash.
  # That's because the descriptor generated here contains an empty
  # "custom" entry.
  def generate_placeholder_descriptor

    # Add persistent errors, to make sure the task cannot be touched.
    if self.errors.blank?
      cur_version = self.tool_config.version_name
      self.errors.add(:base, "The Boutiques Descriptor for version '#{cur_version}' of this task has disappeared. This is a configuration error, contact the administrators.")
      self.errors.add(:base, "A replacement descriptor is currently in use to allow you to view the parameters.")
      self.errors.add(:base, "Because the type information for the parameters is missing, they are all shown as strings.")
      self.errors.add(:unsavable, ": The parameters for this task cannot be modified.") # this special error prevents the save button from working
    end

    # Main descriptor
    fake = BoutiquesSupport::BoutiquesDescriptor.new(
      :name            => self.pretty_type,
      :description     => 'Missing Boutiques Descriptor Placeholder',
      "tool-version"   => self.tool_config.version_name,
      "schema-version" => "0.5",
      "command-line"   => "false", # as in, the unix command 'false'
      :custom          => { 'cbrain:integrator_modules' => {} }, # we can't do better than that
    )

    # Create fake inputs for files
    (self.params[:interface_userfile_ids] || []).each do |userfile_id|
      fake.inputs << BoutiquesSupport::Input.new(
        :id          => "inputfile-#{userfile_id}",
        :name        => "inputfile-#{userfile_id}",
        :type        => 'File',
        :description => "Fake input file",
      )
    end

    # Create fake inputs for all other params (including those that are files)
    (self.invoke_params || {}).keys.each do |input_id|
      fake.inputs << BoutiquesSupport::Input.new(
        :id          => input_id,
        :name        => input_id,
        :type        => 'String',
        :description => "Fake string input for key '#{input_id}'",
      )
    end

    fake
  end

  private

  # Prepare an array with revision information of
  # all the Boutiques integrator modules used by the
  # tools.
  def boutiques_module_information #:nodoc:
    descriptor = self.descriptor_for_final_task_list

    integrator_modules = descriptor.custom['cbrain:integrator_modules'] || {}

    integrator_modules.map do |module_name, _|
      module_name = module_name.constantize
      rev_info    = module_name::Revision_info
      rev_info.format("%f rev. %s %a %d")
    end
  end

end
