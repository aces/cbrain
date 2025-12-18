
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

# A module that provides loading and validaton of Boutiques descriptors.
#
# See also the Boutiques repository: https://github.com/boutiques/boutiques
#
# The module provides one main Ruby class, BoutiquesSupport::BoutiquesDescriptor,
# and several smaller data classes representing components of a descriptor.
# These classes are subclasses of RestrictedHash, a type of Hash class that
# only recognize a select set of keys and raise an exception when other keys
# are used.
#
# Methods of BoutiquesSupport::BoutiquesDescriptor (which inherits from RestrictedHash)
#
# Creation methods:
#
#   desc = BoutiquesSupport::BoutiquesDescriptor.new()     # a blank descriptor
#   desc = BoutiquesSupport::BoutiquesDescriptor.new(hash) # filled from a hash
#   desc = BoutiquesSupport::BoutiquesDescriptor.new_from_string(jsontext)
#   desc = BoutiquesSupport::BoutiquesDescriptor.new_from_file(path_to_json)
#
# Accessor methods:
#
# Note that when an attribute name contains a dash (-) then the corresponding
# method name is written with an underscore (_).
#
#   desc.name = 'SuperTool'  # set the name
#   toolname  = desc.name    # gets the name
#   ver       = desc.tool_version  # gets 'tool-version'
#   inputs    = desc.inputs  # array of BoutiquesSupport::Input objects
#   custom    = desc.custom  # 'custom' object within descriptor
#
# The same conventions apply to Boutiques::Input, Boutiques::OutputFile
# and Boutiques::Group. See the schema of a Boutiques descriptor for the
# list of allowed attributes in each object.
#
# Other utility methods are documented in the source code but might not
# appear in RDOC-generated documentation. Among these, many are
# used by the BoutiquesTask integrator.
#
#
module BoutiquesSupport

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Descriptor schema
  SCHEMA_FILE = "#{Rails.root.to_s}/lib/cbrain_task_generators/schemas/boutiques.schema.json"

  # Read schema, store it in the module.
  @schema = JSON.parse(File.read(SCHEMA_FILE))

  # Utility method to compare a json structure to the Boutiques schema and
  # make sure it matches the specification. Returns an array of error objects,
  # or an empty array if everything is OK.
  def self.validate(json)
    JSON::Validator.fully_validate(
      @schema,
      json,
      :errors_as_objects => true
    )
  end

  # Out of the schema, extract some lists of properties that we will use
  # to restrict our objects.
  top_prop_names    = @schema['properties'].keys
  input_prop_names  = @schema['properties']['inputs']['items']['properties'].keys
  output_prop_names = @schema['properties']['output-files']['items']['properties'].keys
  group_prop_names  = @schema['properties']['groups']['items']['properties'].keys
  cont_prop_names   = @schema['properties']['container-image']['allOf'][1]['oneOf'][0]['properties'].keys

  # Predefine a bunch of classes that act as data holders for
  # the different levels of the Boutiques descriptor.

  class BoutiquesDescriptor < RestrictedHash ; end
  class Input               < RestrictedHash ; end
  class OutputFile          < RestrictedHash ; end
  class Group               < RestrictedHash ; end
  class ContainerImage      < RestrictedHash ; end

  # Now for each of them, configure what keys they are allowed to hold
  BoutiquesDescriptor .allowed_keys = top_prop_names
  Input               .allowed_keys = input_prop_names
  OutputFile          .allowed_keys = output_prop_names
  Group               .allowed_keys = group_prop_names
  ContainerImage      .allowed_keys = cont_prop_names

  # Main class for representing a Boutiques Descriptor
  class BoutiquesDescriptor

    attr_accessor :from_file    # not a hash attribute; a file name, for info


    def initialize(hash={})
      super(hash)
      # The following re-assignments transforms hashes into subobjects (like OutputFile etc)
      # as a side-effect. This is accomplished by the methods later in this class.
      self.inputs            = self.inputs          || []
      self.output_files      = self.output_files    || []
      self.groups            = self.groups          || []
      self.custom            = self.custom          || {}
      self.container_image &&= self.container_image # we need it to remain nil if already nil
      self
    end

    # Creates a new Boutiques object from string
    def self.new_from_string(text)
      json   = JSON.parse(text)
      errors = BoutiquesSupport.validate(json)
      return self.new(json) if errors.blank?
      # Dump errors
      cb_error "Invalid Boutiques descriptor\n" + (errors.map { |e| e[:message] }.join("\n"))
    end

    # Creates a new Boutiques object from a documents stored in a given path
    def self.new_from_file(path)
      obj = self.new_from_string(File.read(path))
      obj.from_file = path
      obj
    end

    def validate #:nodoc:
      BoutiquesSupport.validate(self) # amazingly, the JSON validator also work with our descriptor class
    end

    # When dup'ing, also copy the from_file attribute
    def dup #:nodoc:
      copy = super
      copy.from_file = self.from_file
      # We need to copy explicitely the 'cbrain_input_notes'
      self.inputs = [] if self.inputs.nil?
      copy.inputs.each_with_index do |input,idx|
        input.cbrain_input_notes = self.inputs[idx].cbrain_input_notes.dup
      end
      copy
    end

    # ------------------------------
    # Attribute assignment overrides
    # ------------------------------
    # These methods replaces arrays of plain hashes with arrays
    # of more useful objects (Input, OutputFile, etc)

    def inputs=(array) #:nodoc:
      super( array.map { |elem| BoutiquesSupport::Input.new(elem) } )
    end

    def output_files=(array) #:nodoc:
      super( array.map { |elem| BoutiquesSupport::OutputFile.new(elem) } )
    end

    def groups=(array) #:nodoc:
      super( array.map { |elem| BoutiquesSupport::Group.new(elem) } )
    end

    def container_image=(obj) #:nodoc:
      super( BoutiquesSupport::ContainerImage.new(obj) )
    end

    # ------------------------------
    # Useful utility methods
    # ------------------------------

    # Utility method to convert a string (+str+) to an identifier suitable for a
    # Ruby class name. Similar to Rails' classify, but tries to handle more cases.
    def name_as_ruby_class
      self.name
          .gsub('-', '_')
          .gsub(/\W/, '')
          .gsub(/\A\d/, '')
          .camelize
    end

    # Returns all tags as a flat arra
    def flat_tag_list
      tags = self.tags
      return [] if ! tags
      tags = tags.map do |key,value|
        next key if value == true
        value
      end.flatten
    end

    # Finds a specific Input by id
    def input_by_id(inputid)
      inputs.detect { |x| x.id == inputid } or
        cb_error "No input found with ID '#{inputid}'"
    end

    # Lists optional inputs
    def optional_inputs
      inputs.select { |x| x.optional }
    end

    # Lists required inputs
    def required_inputs
      inputs.select { |x| ! x.optional }
    end

    # Lists inputs
    def list_inputs
      inputs.select { |x| x.list }
    end

    # Lists File inputs
    def file_inputs
      inputs.select { |x| x.type == 'File' }
    end

    # Lists optional File inputs
    def optional_file_inputs
      file_inputs.select { |x| x.optional }
    end

    # Lists mandatory File inputs
    def required_file_inputs
      file_inputs.select { |x| ! x.optional }
    end

    # Return list of mandatory files inputs
    def mandatory_file_inputs
      file_inputs.reject { |input| input.optional }
    end

    # Return the unique mandatory file input, if any;
    # if there are not exactly one mandatory file input,
    # returns nil
    def sole_mandatory_file_input
      all = mandatory_file_inputs
      all.size == 1 ? all[0] : nil
    end

    # Returns true if the descriptor has a single mandatory
    # file input, and that input is NOT a 'list'.
    def qualified_to_launch_multiple_tasks?
      sole_mandatory_file_input && !sole_mandatory_file_input.list
    end

    # Returns a CbrainFileRevision object for the
    # JSON file for the descriptor.
    #
    # Not to be confused with the revision_info() method
    # of BoutiquesSupport itself.
    def file_revision_info
      path = self.from_file
      return CbrainFileRevision.unknown_rev_info if path.blank?
      path = Pathname.new(path)
      if path.absolute?
        path = path.relative_path_from(Pathname.new(Rails.root).parent)
      end
      CbrainFileRevision.for_relpath(path)
    end

    # Given a module name, returns the structure with the
    # data for it stored under the "custom"['cbrain:integrator_modules']
    # entry of the descriptor.
    def custom_module_info(modulename)
      (self.custom['cbrain:integrator_modules'] || {})[modulename]
    end

    # This method pushes a small string (usually
    # a single line of text) that will appear as
    # a note at the top of a parameter form. If
    # the note is already present, the method will
    # do nothing. Returns the current list of notes
    # as an array.
    #
    # Careful, this method mutates the descriptor.
    def add_cbrain_input_note(one_line_note)
      self.custom ||= {}
      notes = self.custom['cbrain:input_notes'] ||= []
      if ! notes.include?(one_line_note)
        notes << one_line_note
      end
      notes
    end

    # Given an invoke structure (like required by bosh, where
    # keys are input IDs and values are input values),
    # this returns the same hash with the substitution tokens
    # as keys (typically, things like { "[BLAH]" => value, ... }
    # The hash only contains entries for inputs that do
    # have a "value-key" defined for them.
    def build_substitutions_by_tokens_hash(invoke_structure)
      self.inputs.map do |input|
        next nil if input.value_key.blank?
        value = invoke_structure[input.id]
        value = input.default_value if value.nil?
        next nil if value.nil?
        [ input.value_key, value ]
      end.compact.to_h
    end

    # Replaces in +string+ all occurrences of the keys in
    # +substitutions_by_tokens+ by the associated values.
    # This is typically used to build a templated string
    # using the "value-key" of the inputs of the descriptor.
    # See also the method build_substitutions_by_tokens_hash()
    # for how to build the substitution hash.
    # The +to_strip+ array contains file extensions to remove from
    # the substituted value before substitution itself.
    def apply_substitutions(string, substitutions_by_tokens, to_strip=[])
      newstring = string.dup
      substitutions_by_tokens.each do |key,val|
        next if val.is_a?(Array) # not supported; what would it mean?
        val = val.to_s
        to_strip.each { |str| val = val.sub(/#{Regexp.quote(str)}\z/,"") }
        newstring = newstring.gsub(key, val)
      end
      newstring
    end

    PRETTY_ORDER_TOP = %w(
      name
      tool-version
      author
      description
      url
      descriptor-url
      online-platform-urls
      doi
      tool-doi
      shell
      command-line
      schema-version
      container-image
      inputs
      groups
      output-files
      error-codes
      suggested-resources
      tags
      tests
      custom
    )
    PRETTY_ORDER_INPUT = %w(
      id
      name
      description
      type
      optional
      integer
      minimum
      exclusive-minimum
      maximum
      exclusive-maximum
      list
      list-separator
      min-list-entries
      max-list-entries
      default-value
      command-line-flag
      command-line-flag-separator
      value-key
      value-choices
      value-disables
      disables-inputs
      requires-inputs
    )
    PRETTY_ORDER_OUTPUT = %w(
      id
      name
      description
      optional
      list
      command-line-flag
      value-key
      path-template
      path-template-stripped-extensions
    )
    PRETTY_ORDER_GROUP = %w(
      id
      name
      description
      all-or-none
      one-is-required
      members
    )

    # Returns a dup() of the current descriptor, but with
    # the fields re-ordered so as to create a 'pretty'
    # layout when printed out (as JSON, YAML etc).
    #
    # The order puts things like the name, description, command
    # version number etc near the top, then then inputs, the
    # groups, the outputs, and the custom sections.
    def pretty_ordered
      ordered  = Hash.new # we use a plain hash to hold the newly ordered elems.
      selfcopy = self.dup
      PRETTY_ORDER_TOP.each { |k| ordered[k] = selfcopy.delete(k).dup if selfcopy.has_key?(k) }
      selfcopy.each { |k,v| puts "Top miss: #{k}" ; ordered[k] = v.dup }
      final = self.class.new(ordered)

      # Order fields in each input
      final.inputs = final.inputs.map do |input|
        ordered  = Hash.new
        selfcopy = input.dup
        PRETTY_ORDER_INPUT.each { |k| ordered[k] = selfcopy.delete(k).dup if selfcopy.has_key?(k) }
        selfcopy.each { |k,v| puts "Inp miss: #{k}" ; ordered[k] = v.dup }
        input.class.new(ordered)
      end

      # Order fields in each output-file
      final.output_files = final.output_files.map do |output|
        ordered  = Hash.new
        selfcopy = output.dup
        PRETTY_ORDER_OUTPUT.each { |k| ordered[k] = selfcopy.delete(k).dup if selfcopy.has_key?(k) }
        selfcopy.each { |k,v| puts "Out miss: #{k}" ; ordered[k] = v.dup }
        output.class.new(ordered)
      end

      # Order fields in each group
      final.groups = final.groups.map do |group|
        ordered  = Hash.new
        selfcopy = group.dup
        PRETTY_ORDER_GROUP.each { |k| ordered[k] = selfcopy.delete(k).dup if selfcopy.has_key?(k) }
        selfcopy.each { |k,v| puts "Group miss: #{k}" ; ordered[k] = v.dup }
        group.class.new(ordered)
      end

      final
    end

    # Returns a JSON text version of the descriptor but with
    # the fields aligned with pretty whitespaces, e.g.
    # instead of
    #
    #   "name": "megatool",
    #   "tool-version": "3.14.15926",
    #   "url": "https://example.com",
    #
    # we get
    #
    #   "name":         "megatool",
    #   "tool-version": "3.14.15926",
    #   "url":          "https://example.com",
    def super_pretty_json

      # Internally, the alignment is made by padding property names with '|'
      # and then stripping them out of the normal JSON generated.
      pad_keys = ->(hash,length) do
        hash.transform_keys! { |k| k.to_s.size >= length ? k : k + ('|' * (length-k.size) ) }
      end
      maxkeylength = ->(hash) { hash.keys.map(&:to_s).map(&:size).max }

      # Returns a modified hash with keys all padded with '|'
      max_pad_keys = ->(hash) do
        copy = HashWithIndifferentAccess.new.merge(hash.dup)
        max  = maxkeylength.(copy)
        pad_keys.(copy,max)
        copy
      end

      final  = HashWithIndifferentAccess.new.merge(self.dup)

      final['inputs'].map!       { |input|  max_pad_keys.(input)  }
      final['output-files'].map! { |output| max_pad_keys.(output) } if final['output-files'].present?
      final['groups'].map!       { |group|  max_pad_keys.(group)  } if final['groups'].present?
      final.delete('groups') if final['groups'].blank?

      final['container-image'] &&= max_pad_keys.(final['container-image'])
      final['custom']          &&= max_pad_keys.(final['custom'])

      final = max_pad_keys.(final)

      json_with_bars = JSON.pretty_generate(final)
      new_json = json_with_bars
        .gsub( /\|+": / ) do |bars|
          spaces = bars.size - 3; '": ' + (' ' * spaces)
        end

      new_json
    end

    #-------------------------------------------------------------------------
    # Methods to access and document CBRAIN specific custom properties
    #-------------------------------------------------------------------------
    # see public/doc/boutiques_extensions for a list of these custom properties

    # Returns a string with name(s) and emails(s) of the Boutiques descriptor authors, enlisted in
    # "cbrain:author" custom property of the descriptors. Emails are optional
    # and should be in angle brackets
    #
    # For example, given the descriptor with
    #
    #    "custom": { "cbrain:author": "Full Name  <email@address.ca>, Co-author Name  <anotheremail@address.org>" }
    #
    # The method returns string
    #    "Full Name  <email@address.ca>, Co-author Name  <anotheremail@address.org>"
    def custom_author
      authors = self.custom['cbrain:author']
      return authors if authors is_a? String
      return authors.join(", ")   #  if author field is arrays
    end

    # Returns Boutiques CBRAIN custom property indicating
    # are forking sub-task(s) allowed. To submit a subtask, a task must create a JSON file
    # named ".new-task-*.json" in the root of its
    # work directory. An example of property definition in a tool descriptor:
    #
    #   "custom: {
    #     "cbrain:can-submit-new-tasks": true
    #   }
    def custom_can_submit_new_tasks
      return self.custom["cbrain:can-submit-new-tasks"]
    end

    # Returns Boutiques CBRAIN custom property indicating
    # the outputs which will not be saved.
    # An example of property definition in a tool descriptor:
    #
    #   "custom: {
    #     "cbrain:ignore_outputs": [output_id_1, output_id_2, output_id_3 ... ]
    #   }
    def custom_ignore_outputs
      return self.custom["cbrain:ignore_outputs"]
    end

    # Returns Boutiques CBRAIN custom property indicating
    # inputs which are saved back to the dataprovider
    # (the original data will be mutated).
    #
    # An example of property definition in a tool descriptor:
    #   "custom: {
    #     "cbrain:save_back_inputs": [id_1, id_2, id_3 ...]
    #   }
    def custom_save_back_inputs
      return self.custom["cbrain:save_back_inputs"]
    end

    # Returns Boutiques CBRAIN custom property indicating
    # that the tool does not modify inputs.
    # An example of property definition in a tool descriptor:
    #
    #   "custom: {
    #     "cbrain:readonly-input-files": true
    #   }
    def custom_readonly_input_files
      return self.custom["cbrain:readonly-input-files"]
    end

    # Returns Boutiques CBRAIN custom property indicating
    # if this task may alter its input files.
    # An example of property definition in a tool descriptor:
    #
    #   "custom: {
    #     "cbrain:alters-input-files": true
    #   }
    def custom_alters_input_files
      return self.custom["cbrain:alters-input-files"]
    end

    # Returns Boutiques CBRAIN custom property indicating for which outputs
    # the usual practice of adding a run id to output file names is cancelled,
    # list of output IDs where no run id inserted. Only allowed for MultiLevel
    # data-providers with "browse path" capability.
    # For listed outputs ids new results overwrite old files.
    # An example of property definition in a tool descriptor:
    #
    #   "custom: {
    #     "cbrain:no-run-id-for-outputs": "id_1, id_2, id_3 .."
    #   }
    def custom_no_run_id_for_outputs
      return self.custom["cbrain:no-run-id-for-outputs"]
    end

    # Returns Boutiques CBRAIN custom property indicating
    # for which inputs an empty string is a valid input.
    # An example of property definition in a tool descriptor:
    #
    #   "custom: {
    #     "cbrain:allow_empty_strings": [input_id]
    #   }
    def custom_allow_empty_strings
      return self.custom["cbrain:allow_empty_strings"]
    end

    # Experimental feature that affects the way tasks are executed.
    # The default implied value is 'simulate'
    # In the mode 'simulate', at the moment of creating
    # the tool's script in cluster_commands(), the
    # output of 'bosh exec simulate' will be substituted in
    # the script to generate the tool's command.
    # In the mode 'launch', an actual 'bosh exec launch' command
    # will be put in the script instead.
    # An example of property definition in a tool descriptor:
    #
    #   "custom: {
    #     "cbrain:boutiques_bosh_exec_mode": "launch"
    #   }
    def custom_boutiques_bosh_exec_mode
      return self.custom["cbrain:boutiques_bosh_exec_mode"]
    end

    # An advanced feature for seasoned CBRAIN experts only. That allows
    # overwrite the standard task behavior with custom class.
    # An example of property definition in a tool descriptor:
    #   "custom: {
    #     "cbrain:inherits-from-class": "MyClassName"
    #   }
    def custom_inherits_from_class
      return self.custom["cbrain:inherits-from-class"]
    end

  end  # class BoutiquesSupport::BoutiquesDescriptor

  #------------------------------------------------------
  # Aditional methods for the sub-objects of a descriptor
  #------------------------------------------------------

  # Adds a comparison operator to these subobjects so that
  # they can be sorted.
  # See also Hash.resorted in the CBRAIN core extensions.
  [ Input, OutputFile, Group ].each do |klass|
    klass.send(:define_method, :'<=>') { |other| self.id <=> other.id }
  end

  class Input

    attr_accessor :cbrain_input_notes # array of bulletpoints to show in form

    # When dup'ing, also copy the special cbrain_input_notes
    def dup #:nodoc:
      copy = super
      copy.cbrain_input_notes = self.cbrain_input_notes.dup
      copy
    end

    # This method returns the parameter name for an input identified
    # by input_id.
    # We put all input Boutiques parameters under a 'invoke' substructure.
    # E.g. for a input with ID 'abcd' in a task, we'll find the value
    # in task.params['invoke']['abcd'] and the parameter name is thus
    # "invoke[abcd]". The as_list option appends "[]" to the name
    # to make it an array parameter.
    def self.cb_invoke_name(input_id, as_list = nil) #:nodoc:
      return "invoke[#{input_id}][]" if as_list
      return "invoke[#{input_id}]"
    end

    def self.cb_invoke_html_name(input_id, force_list = nil) #:nodoc:
      self.cb_invoke_name(input_id, force_list).to_la
    end

    def self.cb_invoke_html_id(input_id, force_list = nil) #:nodoc:
      self.cb_invoke_name(input_id, force_list).to_la_id
    end

    # Returns the parameter name of the input; this just
    # invokes the class method of the same name,
    # passing it the ID of the Input object.
    #
    # If force_list is nil, the input's "list" flag
    # will determine if we return a name for an array
    # parameter. If set to true or false, it will force
    # it one way or the other, ignoring the value of "list".
    def cb_invoke_name(force_list = nil)
      as_list = (self.list && force_list.nil?) || force_list == true
      self.class.cb_invoke_name(self.id, as_list)
    end

    def cb_invoke_html_name(force_list = nil) #:nodoc:
      as_list = (self.list && force_list.nil?) || force_list == true
      self.class.cb_invoke_html_name(self.id, as_list)
    end

    def cb_invoke_html_id(force_list = nil) #:nodoc:
      as_list = (self.list && force_list.nil?) || force_list == true
      self.class.cb_invoke_html_id(self.id, as_list)
    end

  end # class BoutiquesSupport::Input

end
