
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
# The module provides one main Ruby class, +BoutiquesSupport::BoutiquesDescriptor+,
# and several smaller data classes representing components of a descriptor.
# These classes are subclasses of RestrictedHash, a type of Hash class that
# only recognize a select set of keys and raise an exception when other keys
# are used.
#
# ==Methods of +BoutiquesSupport::BoutiquesDescriptor+
# which inherits from RestrictedHash
#
# ===Creation methods:
#
#   desc = BoutiquesSupport::BoutiquesDescriptor.new()     # a blank descriptor
#   desc = BoutiquesSupport::BoutiquesDescriptor.new(hash) # filled from a hash
#   desc = BoutiquesSupport::BoutiquesDescriptor.new_from_string(jsontext)
#   desc = BoutiquesSupport::BoutiquesDescriptor.new_from_file(path_to_json)
#
# ===Accessor methods:
#
# Note that when an attribute name contains a dash (-) then the corresponding
# method name is written with an underscore (_).
#
#   desc.name = 'SuperTool'  # set the name
#   toolname  = desc.name    # gets the name
#   ver       = desc.tool_version  # gets 'tool-version'
#   inputs    = desc.inputs  # array of +BoutiquesSupport::Input+ objects
#   custom    = desc.custom  # 'custom' object within descriptor
#
# The same conventions apply to
# +BoutiquesSupport::Input+,
# +BoutiquesSupport::OutputFile+
# and +BoutiquesSupport::Group+.
# See the schema of a Boutiques descriptor for the list of allowed attributes
# in each object.
#
# Other utility methods are documented in the source code but might not
# appear in RDOC-generated documentation. Among these, many are
# used by the BoutiquesTask integrator.
#
# A number of BoutiquesDescriptor methods provide access to 'custom',
# {CBRAIN-specific properties}[../../public/doc/cbrain_boutiques_extensions/cbrain_properties.txt]
# of a descriptor. Such methods start with +custom+ prefix. It is strongly recommended to use these
# methods rather than via +custom+ methods attributes.
# We details these and few other utility methods below
module BoutiquesSupport

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Descriptor schema
  # = class BoutiquesDescriptor
  # is a closure in this module, and thus can access both schema and data extracted using it
  SCHEMA_FILE = "#{Rails.root.to_s}/lib/cbrain_task_generators/schemas/boutiques.schema.json"

  # Attention! below we define anonymous class BoutiquesDescriptor
  # and it's methods for rdoc. rdoc skips anonymous classes so we have to
  # do it before of after


  # :section: Utility methods of BoutiquesDescriptor

  # :method: super_pretty_json
  # Generates a JSON with nice spacing

  # :section: Utility methods of BoutiquesDescriptor

  # :method: pretty_ordered
  # Returns a new descriptor with the attributes in a canonical beautiful order


  # :section: Utility methods of BoutiquesDescriptor

  # :method: apply_substitutions
  # Utility to perform the substitutions of tokens in a string
  # :call-seq:
  #   apply_substitutions(string, substitutions_by_tokens, to_strip=[])


  # :section: Utility methods of BoutiquesDescriptor

  # :method: build_substitutions_by_tokens_hash
  # Utility for building a replacement hash for the inputs based on
  # the values in invoke_structure
  # :call-seq:
  #   build_substitutions_by_tokens_hash(invoke_structure)


  # :section: Getter methods of BoutiquesDescriptor for CBRAIN specific properties of the descriptor custom section

  # :method: custom_module_info
  # Given a module name, returns the structure with the
  # data for it stored under the "custom"['cbrain:integrator_modules']
  # entry of the descriptor.
  # All these modules are well documented with rdoc, and can be found in the +lib+ subdirectory
  # of CBRAIN itself or a plugin; their names start with +Boutiques+ prefix.
  # :call-seq:
  #   custom_module_info(modulename)


  # :section: Other getters of BoutiquesDescriptor class

  # :method: required_file_inputs
  # List of File inputs that are mandatory


  # :section: Other getters of BoutiquesDescriptor class

  # :method: optional_file_inputs
  # List of File inputs that are optional


  # :section: Other getters of BoutiquesDescriptor class

  # :method: file_inputs
  # File inputs


  # :section: Other getters of BoutiquesDescriptor class

  # :method: list_inputs
  # Multi-valued inputs


  # :section: Other getters of BoutiquesDescriptor class

  # :method: required_inputs
  # Mandatory inputs


  # :section: Other getters of BoutiquesDescriptor class

  # :method: optional_inputs
  # Optional inputs


  # :section: Other getters of BoutiquesDescriptor class

  # :method: input_by_id
  # Finds a specific BoutiquesSupport:Input by ID
  # :call-seq:
  #   input_by_id(inputid)


  # :section: Other getters of BoutiquesDescriptor class

  # :method: flat_tag_list
  # Returns all tags as a flat array


  # :section: Utility methods of BoutiquesDescriptor

  # :method: name_as_ruby_class
  # Returns the name of the tool NNNN, appropriate to use as
  # a class name as BoutiquesTask::NNNN


  # :section: Getter methods of BoutiquesDescriptor for CBRAIN specific properties of the descriptor custom section

  # :method: custom_inherits_from_class
  # An advanced feature for seasoned CBRAIN experts only, that allows
  # overwrite the standard task behavior with custom class.
  # An example of property definition in a tool descriptor:
  #   "custom: {
  #     "cbrain:inherits-from-class": "MyClassName"
  #   }
  #


  # :section: Getter methods of BoutiquesDescriptor for CBRAIN specific properties of the descriptor custom section

  # :method: custom_can_submit_new_tasks
  # (Experimental)
  # A method of BoutiquesDescriptor.Returns Boutiques CBRAIN custom property indicating
  # are forking sub-task(s) allowed. To submit a subtask, a task must create a JSON file
  # named ".new-task-*.json"  at the root of its
  # work directory.
  # An example of property definition in a tool descriptor:
  #   "custom: {
  #     "cbrain:can-submit-new-tasks": true
  #   }


  # :section: Getter methods of BoutiquesDescriptor for CBRAIN specific properties of the descriptor custom section

  # :method: custom_author
  # Returns a string with name(s) and emails(s) of the Boutiques descriptor authors, enlisted in
  # "cbrain:author" custom property of the descriptors. Emails are optional
  # and should be in angle brackets.
  #
  # For example, given the descriptor with
  #    "custom": { "cbrain:author": "Full Name  <email@address.ca>, Co-author Name  <anotheremail@address.org>" }
  # The method returns string
  #    "Full Name  <email@address.ca>, Co-author Name  <anotheremail@address.org>"


  # :section: Getter methods of BoutiquesDescriptor for CBRAIN specific properties of the descriptor custom section

  # :method: custom_ignore_outputs
  # Returns Boutiques CBRAIN custom property indicating
  # the outputs which will not be saved.
  # An example of property definition in a tool descriptor:
  #   "custom: {
  #     "cbrain:ignore_outputs": [output_id_1, output_id_2, output_id_3 ... ]
  #   }


  # :section: Getter methods of BoutiquesDescriptor for CBRAIN specific properties of the descriptor custom section

  # :method: custom_save_back_inputs
  # Returns Boutiques CBRAIN custom property indicating
  # inputs which are saved back to the dataprovider (the original data will be mutated).
  # An example of property definition in a tool descriptor:
  #   "custom: {
  #     "cbrain:save_back_inputs": [id_1, id_2, id_3 ...]
  #   }


  # :section: Getter methods of BoutiquesDescriptor for CBRAIN specific properties of the descriptor custom section

  # :method: custom_readonly_input_files
  # Returns Boutiques CBRAIN custom property indicating
  # that the tool does not modify inputs.
  # An example of property definition in a tool descriptor:
  #   "custom: {
  #     "cbrain:readonly-input-files": true
  #   }


  # :section: Getter methods of BoutiquesDescriptor for CBRAIN specific properties of the descriptor custom section

  # :method: custom_alters_input_files
  # Returns Boutiques CBRAIN custom property indicating
  # if this task may alter its input files.
  # An example of property definition in a tool descriptor:
  #   "custom: {
  #     "cbrain:alters-input-files": true
  #   }


  # :section: Getter methods of BoutiquesDescriptor for CBRAIN specific properties of the descriptor custom section

  # :method: custom_no_run_id_for_outputs
  # Returns Boutiques CBRAIN custom property indicating for which outputs
  # the usual practice of adding a run id to output file names is cancelled,
  # list of output IDs where no run id inserted. Only allowed for MultiLevel
  # data-providers with "browse path" capability.
  # For listed outputs ids new results overwrite old files.
  # An example of property definition in a tool descriptor:
  #   "custom: {
  #     "cbrain:no-run-id-for-outputs": []id_1, id_2, id_3 ...]
  #   }


  # :section: Getter methods of BoutiquesDescriptor for CBRAIN specific properties of the descriptor custom section

  # :method: custom_allow_empty_strings
  # Returns Boutiques CBRAIN custom property indicating
  # for which inputs an empty string is a valid input.
  # An example of property definition in a tool descriptor:
  #   "custom: {
  #     "cbrain:allow_empty_strings": [input_id]
  #   }


  # :section: Getter methods of BoutiquesDescriptor for CBRAIN specific properties of the descriptor custom section

  # :method: custom_boutiques_bosh_exec_mode
  # Experimental
  # The default implied value is 'simulate'
  # In the mode 'simulate', at the moment of creating
  # the tool's script in cluster_commands(), the
  # output of 'bosh exec simulate' will be substituted in
  # the script to generate the tool's command.
  # In the mode 'launch', an actual 'bosh exec launch' command
  # will be put in the script instead.
  # An example of property definition in a tool descriptor:
  #   "custom: {
  #     "cbrain:boutiques_bosh_exec_mode": "launch"
  #   }


  # :section: Utility methods of +class Input+

  # :method: cb_invoke_name
  # This method return the parameter name for the input.
  # We put all input Boutiques parameters under a 'invoke' substructure.
  # E.g. for a input with ID 'abcd' in a task, we'll find the value
  # in task.params['invoke']['abcd'] and the parameter name is thus
  # "invoke[abcd]"

  # :section: Utility methods of +class Input+

  # :method: cb_invoke_html_name


  # :section: Utility methods of +class Input+

  # :method: cb_invoke_html_id


  # Read schema, extract some name lists
  @schema = JSON.parse(File.read(SCHEMA_FILE))

  # Out of the schema, extract list of properties that we will use
  # to restrict our objects.
  top_prop_names    = @schema['properties'].keys
  input_prop_names  = @schema['properties']['inputs']['items']['properties'].keys
  output_prop_names = @schema['properties']['output-files']['items']['properties'].keys
  group_prop_names  = @schema['properties']['groups']['items']['properties'].keys
  cont_prop_names   = @schema['properties']['container-image']['allOf'][1]['oneOf'][0]['properties'].keys

  def self.validate(json) # :nodoc:
    JSON::Validator.fully_validate(
      @schema,
      json,
      :errors_as_objects => true
    )
  end

  # The following assignment is pretty much like
  #   class BoutiquesDescriptor < RestrictedHash
  # except we have a closure and we can access the variables
  # initialize above (top_prop_names etc).
  BoutiquesDescriptor = Class.new(RestrictedHash) do |klass|

    allowed_keys top_prop_names # 'name', 'author' etc
    attr_accessor :from_file    # not a hash attribute; a file name, for info

    Input          = Class.new(RestrictedHash) { allowed_keys input_prop_names  }
    OutputFile     = Class.new(RestrictedHash) { allowed_keys output_prop_names }
    Group          = Class.new(RestrictedHash) { allowed_keys group_prop_names  }
    ContainerImage = Class.new(RestrictedHash) { allowed_keys cont_prop_names   }

    # Adds a comparison operator to these subobjects so that
    # they can be sorted.
    # See also Hash.resorted in the CBRAIN core extensions.
    [ Input, OutputFile, Group ].each do |klass|
      klass.send(:define_method, :'<=>') { |other| self.id <=> other.id }
    end

    def initialize(hash={})
      super(hash)
      # The following re-assignment transforms hashed into subobjects (like OutputFile etc)
      # as a side-effect. This is accomplished by the methods later in this class.
      self.inputs            = self.inputs          || []
      self.output_files      = self.output_files    || []
      self.groups            = self.groups          || []
      self.custom            = self.custom          || {}
      self.container_image &&= self.container_image # we need it to remain nil if already nil
      self
    end

    def self.new_from_string(text)
      json   = JSON.parse(text)
      errors = BoutiquesSupport.validate(json)
      return self.new(json) if errors.blank?
      # Dump errors
      cb_error "Invalid Boutiques descriptor\n" + (errors.map { |e| e[:message] }.join("\n"))
    end

    def self.new_from_file(path)
      obj = self.new_from_string(File.read(path))
      obj.from_file = path
      obj
    end

    def validate
      BoutiquesSupport.validate(self) # amazingly, the JSON validator also work with our descriptor class
    end

    # When dup'ing, also copy the from_file attribute
    def dup #:nodoc:
      copy = super
      copy.from_file = self.from_file
      copy
    end

    # ------------------------------
    # Attribute assignment overrides
    # ------------------------------
    # These methods replaces arrays of plain hashes with arrays
    # of more useful objects (Input, OutputFile, etc)

    def inputs=(array) #:nodoc:
      super( array.map { |elem| Input.new(elem) } )
    end

    def output_files=(array) #:nodoc:
      super( array.map { |elem| OutputFile.new(elem) } )
    end

    def groups=(array) #:nodoc:
      super( array.map { |elem| Group.new(elem) } )
    end

    def container_image=(obj) #:nodoc:
      super( ContainerImage.new(obj) )
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

    def flat_tag_list
      tags = self.tags
      return [] if ! tags
      tags = tags.map do |key,value|
        next key if value == true
        value
      end.flatten
    end

    def input_by_id(inputid)
      inputs.detect { |x| x.id == inputid } or
        cb_error "No input found with ID '#{inputid}'"
    end

    def optional_inputs
      inputs.select { |x| x.optional }
    end

    def required_inputs
      inputs.select { |x| ! x.optional }
    end

    def list_inputs
      inputs.select { |x| x.list }
    end

    def file_inputs
      inputs.select { |x| x.type == 'File' }
    end

    def optional_file_inputs
      file_inputs.select { |x| x.optional }
    end

    def required_file_inputs
      file_inputs.select { |x| ! x.optional }
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

    #-------------------------------------------------------------------------
    # Methods to access and document CBRAIN specific custom properties
    #-------------------------------------------------------------------------
    # see public/doc/boutiques_extensions for a list of these custom properties

    # Returns a string with name(s) and emails(s) of the Boutiques descriptor authors, enlisted in
    # "cbrain:author" custom property of the descriptors. Emails are optional
    # and should be in angle brackets
    #
    # For example, given the descriptor with
    #    "custom": { "cbrain:author": "Full Name  <email@address.ca>, Co-author Name  <anotheremail@address.org>" }
    # The method returns string
    #    "Full Name  <email@address.ca>, Co-author Name  <anotheremail@address.org>"
    def custom_author
      authors = self.custom['cbrain:author']
      return authors if authors is_a? String
      return authors.join(", ")   #  if author field is arrays
    end

    # Returns Boutiques CBRAIN custom property indicating
    # are forking sub-task(s) allowed. To submit a subtask, a task must create a JSON file
    # named ".new-task-*.json"  at the root of its
    # work directory.
    # An example of property definition in a tool descriptor:
    #   "custom: {
    #     "cbrain:can-submit-new-tasks": true
    #   }
    def custom_can_submit_new_tasks
      return self.custom["cbrain:can-submit-new-tasks"]
    end

    # Returns Boutiques CBRAIN custom property indicating
    # the outputs which will not be saved.
    # An example of property definition in a tool descriptor:
    #   "custom: {
    #     "cbrain:ignore_outputs": [output_id_1, output_id_2, output_id_3 ... ]
    #   }
    def custom_ignore_outputs
      return self.custom["cbrain:ignore_outputs"]
    end

    # Returns Boutiques CBRAIN custom property indicating
    # inputs which are saved back to the dataprovider
    # (the original data will be mutated).
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
    #   "custom: {
    #     "cbrain:readonly-input-files": true
    #   }
    def custom_readonly_input_files
      return self.custom["cbrain:readonly-input-files"]
    end

    # Returns Boutiques CBRAIN custom property indicating
    # if this task may alter its input files.
    # An example of property definition in a tool descriptor:
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
    #   "custom: {
    #     "cbrain:no-run-id-for-outputs": "id_1, id_2, id_3 .."
    #   }
    def custom_no_run_id_for_outputs
      return self.custom["cbrain:no-run-id-for-outputs"]
    end

    # Returns Boutiques CBRAIN custom property indicating
    # for which inputs an empty string is a valid input.
    # An example of property definition in a tool descriptor:
    #   "custom: {
    #     "cbrain:allow_empty_strings": [input_id]
    #   }
    def custom_allow_empty_strings
      return self.custom["cbrain:allow_empty_strings"]
    end

    # Experimental
    # The default implied value is 'simulate'
    # In the mode 'simulate', at the moment of creating
    # the tool's script in cluster_commands(), the
    # output of 'bosh exec simulate' will be substituted in
    # the script to generate the tool's command.
    # In the mode 'launch', an actual 'bosh exec launch' command
    # will be put in the script instead.
    # An example of property definition in a tool descriptor:
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

    # Given a module name, returns the structure with the
    # data for it stored under the "custom"['cbrain:integrator_modules']
    # entry of the descriptor.
    # All modules can be found in the lib subdirectory of a CBRAIN plugin
    # or CBRAIN itself and start with Boutiques prefix.
    def custom_module_info(modulename)
      self.custom['cbrain:integrator_modules'][modulename]
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

    # Replaces in +string+ all occurences of the keys in
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

    #------------------------------------------------------
    # Aditional methods for the sub-objects of a descriptor
    #------------------------------------------------------

    class Input

      # This method return the parameter name for the input.
      # We put all input Boutiques parameters under a 'invoke' substructure.
      # E.g. for a input with ID 'abcd' in a task, we'll find the value
      # in task.params['invoke']['abcd'] and the parameter name is thus
      # "invoke[abcd]"
      def cb_invoke_name(force_list = nil)
        if (self.list && force_list.nil?) || force_list == true
          "invoke[#{self.id}][]"
        else # self.list is false, or force_list is false
          "invoke[#{self.id}]"
        end
      end

      def cb_invoke_html_name(force_list = nil)
        cb_invoke_name(force_list).to_la
      end

      def cb_invoke_html_id(force_list = nil)
        cb_invoke_html_name(force_list).to_la_id
      end

    end

  end

end
