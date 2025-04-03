
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
# The modules provides one main Ruby class, BoutiquesSupport::BoutiquesDescriptor,
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
#   # Returns the name of the tool NNNN, appropriate to use as
#   # a class name as BoutiquesTask::NNNN
#   desc.name_as_ruby_class
#
#   # Returns all tags as a flat array
#   desc.flat_tag_list
#
#   # Finds a specific BoutiquesSupport:Input by ID
#   desc.input_by_id(inputid)
#
#   # Subset of the list of inputs with just the optional ones
#   desc.optional_inputs
#
#   # Subset of the list of inputs with just the mandatory ones
#   desc.required_inputs
#
#   # Subset of the list of inputs with just the multi-valued ones
#   desc.list_inputs
#
#   # Subset of the list of inputs with just the File inputs
#   desc.file_inputs
#
#   # List of File inputs that are optional
#   desc.optional_file_inputs
#
#   # List of File inputs that are mandatory
#   desc.required_file_inputs
#
#   # Returns the entry for a custom Boutiques integration module
#   desc.custom_module_info(modulename)
#
#   # Utility for building a replacement hash for the inputs based on
#   # the values in invoke_structure
#   desc.build_substitutions_by_tokens_hash(invoke_structure)
#
#   # Utility to perform the subsitutions of tokens in a string
#   desc.apply_substitutions(string, substitutions_by_tokens, to_strip=[])
#
#   # Returns a new descriptor with the attributes in a canonical beautiful order
#   desc.pretty_ordered
#
#   # Generates a JSON with nice spacing
#   desc.super_pretty_json
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
    attr_accessor :mtime_of_file # not a hash attribute, a file timestamp, for caching


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

    def self.new_from_string(text)
      json   = JSON.parse(text)
      errors = BoutiquesSupport.validate(json)
      return self.new(json) if errors.blank?
      # Dump errors
      cb_error "Invalid Boutiques descriptor\n" + (errors.map { |e| e[:message] }.join("\n"))
    end

    def self.new_from_file(path)
      obj = self.new_from_string(File.read(path))
      obj.from_file     = path
      obj.mtime_of_file = File.mtime(path)
      obj
    end

    def reload_if_file_timestamp_changed()
      filepath = self.from_file
      return self if filepath.blank? || (File.mtime(filepath) - self.mtime_of_file ).abs < 1
      self.class.new_from_file(filepath)
    end

    def validate
      BoutiquesSupport.validate(self) # amazingly, the JSON validator also work with our descriptor class
    end

    # When dup'ing, also copy the from_file attribute
    def dup #:nodoc:
      copy = super
      copy.from_file     = self.from_file
      copy.mtime_of_file = self.mtime_of_file
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

  end # class BoutiquesSupport::Input

end
