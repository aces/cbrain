
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

module CBRAINExtensions #:nodoc:

  module ActiveRecordExtensions #:nodoc:

    module AbstractModelMethods #:nodoc:

      Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

      def self.included(includer) #:nodoc:
        includer.class_eval do
          extend ClassMethods
        end
      end

      def before_create_check_if_abstract_model #:nodoc:
        cb_error "Cannot create object of class #{self.class}: it's an abstract model." if
          self.class.cbrain_abstract_model?
        true
      end

      # ActiveRecord extensions to tag some ActiveRecord single table
      # inheritance models as 'abstract'.
      module ClassMethods

        # Prevent instantiating an object if the class has been flagged
        # as a cbrain_abstract_model .
        #def new(*args) #:nodoc:
        #  raise "Cannot instantiate a CBRAIN abstract model." if self.cbrain_abstract_model?
        #  super(*args)
        #end

        # Turns on a flag to label a class as abstract,
        # so that the user interface doesn't provide it
        # as an option for the users.
        def cbrain_abstract_model!
          @_cbrain_abstract_model_ = true
          before_create :before_create_check_if_abstract_model
        end

        # Returns whether or not the current class
        # is abstract, as far as CBRAIN is concerned;
        # such class should not be used to instantiate
        # real objects in STI contexts.
        def cbrain_abstract_model?
          defined?(@_cbrain_abstract_model_) && @_cbrain_abstract_model_ == true
        end

      end # module ClassMethods

    end # module AbstractModelMethods

  end # module ActiveRecord

end # module CBRAINExtensions

