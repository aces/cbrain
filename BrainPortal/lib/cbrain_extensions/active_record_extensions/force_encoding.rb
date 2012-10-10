
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
    
    # ActiveRecord Added Behavior For Data Typing
    module ForceEncoding
      
      Revision_info=CbrainFileRevision[__FILE__] #:nodoc:
      
      def self.included(includer) #:nodoc:
        includer.class_eval do
          extend ClassMethods
        end
      end
      
      # Called automatically after a record is reloaded (it's an
      # after_initalize() callback) if the directive
      # force_text_attribute_encoding was used.
      def adjust_forced_attribute_encodings #:nodoc:
        to_adjust = self.class.cbrain_forced_attribute_encodings
        return true unless to_adjust
        return true if     to_adjust.empty?
        to_adjust.each do |att,enc_name|
          self.send(att).force_encoding(enc_name) rescue nil # seems to work in Rails 3.0.7, and record not ".changed?"
          #self.write_attribute(att, self.send(att).force_encoding(enc_name)) rescue nil # seems to work in Rails 3.0.7
        end
        true
      end
      
      module ClassMethods
        attr_accessor :cbrain_forced_attribute_encodings # cattr_accessor is from Rails

        # This directive adds an after_initalize() callback such that
        # attributes stored as :text in the schema are always reloaded
        # with a forced encoding. In a model:
        #
        #   force_attribute_encoding encoding_name, :att [, :att, ...]
        def force_text_attribute_encoding(encoding_name, *attlist)
          return unless self.table_exists?

          to_adjust = self.cbrain_forced_attribute_encodings ||= {}
          enc = Encoding.find(encoding_name) rescue nil
          raise "No such encoding '#{encoding_name}'." unless enc
          raise "Need a list of :text attributes to adjust." if attlist.empty?
          attlist.each do |att|
            raise "Attribute '#{att}' not a symbol?!?" unless att.is_a?(Symbol)
            colinfo = self.columns_hash[att.to_s] || self.columns_hash[att]
            next unless colinfo
            next unless colinfo.type == :text || colinfo.type == :string
            to_adjust[att] = encoding_name
          end
          after_initialize :adjust_forced_attribute_encodings
        end
      end
      
    end
  end
end
