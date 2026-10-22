
#
# CBRAIN Project
#
# Copyright (C) 2008-2012
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

require "cbrain_file_revision"
require "cbrain_extensions"

###################################################################
# CBRAIN ActiveRecord extensions
###################################################################
module ActiveRecord #:nodoc:

  # CBRAIN ActiveRecord::Relation extensions
  class Relation #:nodoc:

    #####################################################################
    # ActiveRecord::Relation safety net to avoid OoM conditions
    #####################################################################

    prepend CbrainExtensions::ActiveRecordExtensions::RelationExtensions::SafeInspect

    #####################################################################
    # ActiveRecord::Relation Added Behavior For API Requests
    #####################################################################

    include CbrainExtensions::ActiveRecordExtensions::RelationExtensions::ForApiRequests

  end


  #####################################################################
  # Prettier inspect() for associations (mostly for console)
  #####################################################################

  class AssociationRelation
    prepend CbrainExtensions::ActiveRecordExtensions::RelationExtensions::SafeInspect
  end

  module Associations
    class CollectionProxy
      prepend CbrainExtensions::ActiveRecordExtensions::RelationExtensions::SafeInspect
    end
  end

end

