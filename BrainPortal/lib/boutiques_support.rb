
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

  BoutiquesDescriptor = Class.new(RestrictedHash) do |klass|

    allowed_keys top_prop_names # 'name', 'author' etc

    Input          = Class.new(RestrictedHash) { |klass| allowed_keys input_prop_names  }
    OutputFile     = Class.new(RestrictedHash) { |klass| allowed_keys output_prop_names }
    Group          = Class.new(RestrictedHash) { |klass| allowed_keys group_prop_names  }
    ContainerImage = Class.new(RestrictedHash) { |klass| allowed_keys cont_prop_names   }

    def initialize(hash={})
      super(hash)
      # The following re-assignment transforms hashed into subobjects (like OutputFile etc)
      # as a side-effect. This is accomplished by the methods later in this class.
      self.inputs            = self.inputs          || []
      self.output_files      = self.output_files    || []
      self.groups            = self.groups          || []
      self.container_image &&= self.container_image # we need to to remain nil if already nil
      self.custom          &&= self.custom
      self
    end

    def self.new_from_string(text)
      self.new(JSON.parse(text))
    end

    def self.new_from_file(path)
      self.new_from_string(File.read(path))
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
    # Userful utility methods
    # ------------------------------

    def input_by_id(inputid)
      inputs.detect { |x| x.id == input_id } or
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

    class Input

      # This method return the parameter name for the input.
      # We put all input Boutiques parameters under a 'invoke' substructure.
      # E.g. for string input 'abcd' in a task, we'll find the value
      # in task.params['invoke']['abcd'] and the parameter name is thus
      # "invoke[abcd]"
      def cb_invoke_name
        if self.list
          "invoke[#{self.id}][]" # .to_la is a String method added by CBRAIN
        else
          "invoke[#{self.id}]"
        end
      end

    end

  end

end
