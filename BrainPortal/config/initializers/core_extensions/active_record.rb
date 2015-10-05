
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

###################################################################
# CBRAIN ActiveRecord extensions
###################################################################
module ActiveRecord #:nodoc:

  # CBRAIN ActiveRecord::Base extensions
  class Base


    ###################################################################
    # ActiveRecord Added Behavior For MetaData
    ###################################################################

    include ActRecMetaData # module in lib/act_rec_meta_data.rb

    ###################################################################
    # ActiveRecord Added Behavior For Logging
    ###################################################################

    include ActRecLog # module in lib/act_rec_log.rb

    ############################################################################
    # Pretty Type methods
    ############################################################################

    include CBRAINExtensions::ActiveRecordExtensions::PrettyType

    ###################################################################
    # ActiveRecord Added Behavior For Single Table Inheritance
    ###################################################################

    include CBRAINExtensions::ActiveRecordExtensions::SingleTableInheritance

    ###################################################################
    # ActiveRecord Added Behavior For Single Table Inheritance
    ###################################################################

    include CBRAINExtensions::ActiveRecordExtensions::AbstractModelMethods

    ###################################################################
    # Helpers to manage mass-assignable attributes.
    ###################################################################

    include CBRAINExtensions::ActiveRecordExtensions::MassAssignmentAuthorization

    ###################################################################
    # ActiveRecord Added Behavior For Data Typing
    ###################################################################

    include CBRAINExtensions::ActiveRecordExtensions::ForceEncoding

    ###################################################################
    # ActiveRecord Added Behavior For Serialization
    ###################################################################

    include CBRAINExtensions::ActiveRecordExtensions::Serialization

    ###################################################################
    # ActiveRecord Added Behavior For Core Models
    ###################################################################

    include CBRAINExtensions::ActiveRecordExtensions::CoreModels

    ###################################################################
    # ActiveRecord Added Behavior For Hiding Attributes
    ###################################################################

    include CBRAINExtensions::ActiveRecordExtensions::HiddenAttributes

    ###################################################################
    # +scopes+ method behaviour lost in Rails 3.1.
    ###################################################################

    include CBRAINExtensions::ActiveRecordExtensions::CbrainScopes

  end # class Base of ActiveRecord



  # CBRAIN ActiveRecord::Relation extensions
  class Relation

    #####################################################################
    # ActiveRecord::Relation Added Behavior For Unstructured Data Fetches
    #####################################################################

    include CBRAINExtensions::ActiveRecordExtensions::RelationExtensions::RawData

  end

  # CBRAIN ActiveRecord::Associations::CollectionProxy extensions
  # delegating extended Relation methods.
  module Associations #:nodoc:
    class CollectionProxy #:nodoc:
      delegate :raw_first_column, :raw_rows, :to => :scoped
    end
  end

end


