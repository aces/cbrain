
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
      self.inputs          = self.inputs          || []
      self.output_files    = self.output_files    || []
      self.groups          = self.groups          || []
      self.container_image = self.container_image || {}
      self
    end

    def inputs=(array)
      super( array.map { |elem| Input.new(elem) } )
    end

    def output_files=(array)
      super( array.map { |elem| OutputFile.new(elem) } )
    end

    def groups=(array)
      super( array.map { |elem| Group.new(elem) } )
    end

    def container_image=(obj)
      super( ContainerImage.new(obj) )
    end

  end

end
