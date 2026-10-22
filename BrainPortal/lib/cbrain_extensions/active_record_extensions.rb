
#
# CBRAIN Project
#
# Copyright (C) 2008-2026
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

module CbrainExtensions::ActiveRecordExtensions

  require_relative "active_record_extensions/abstract_model_methods"
  require_relative "active_record_extensions/api_attr_visible"
  require_relative "active_record_extensions/attribute_serialization"
  require_relative "active_record_extensions/core_models"
  require_relative "active_record_extensions/hidden_attributes"
  require_relative "active_record_extensions/pretty_type"
  require_relative "active_record_extensions/record_serialization"
  require_relative "active_record_extensions/relation_extensions"
  require_relative "active_record_extensions/single_table_inheritance"

end
