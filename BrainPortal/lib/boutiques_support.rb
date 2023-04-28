
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

module BoutiquesSupport

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Descriptor schema
  SCHEMA_FILE = "#{Rails.root.to_s}/lib/cbrain_task_generators/schemas/boutiques.schema.json"

  # Read schema, extract some name lists
  @schema = JSON.parse(File.read(SCHEMA_FILE))

  # Out of the schema, extract list of properties that we will use
  # to restrict our objects.
  top_prop_names    = @schema['properties'].keys
  input_prop_names  = @schema['properties']['inputs']['items']['properties'].keys
  output_prop_names = @schema['properties']['output-files']['items']['properties'].keys
  group_prop_names  = @schema['properties']['groups']['items']['properties'].keys
  cont_prop_names   = @schema['properties']['container-image']['allOf'][1]['oneOf'][0]['properties'].keys

  def self.validate(json)
    JSON::Validator.fully_validate(
      @schema,
      json,
      :errors_as_objects => true
    )
  end

  # The following assignement is pretty much like
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

    # Given a module name, returns the structure with the
    # data for it stored under the "custom"['cbrain:integrator_modules']
    # entry of the descriptor.
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
