
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
module ActiveRecord

  class Base

    ############################################################################
    # Pretty Type methods
    ############################################################################

    # Default 'pretty' type name for the model.
    def self.pretty_type
      self.to_s.demodulize.underscore.titleize
    end

    # Default 'pretty' type name for the object.
    def pretty_type
      self.class.pretty_type
    end

    ###################################################################
    # ActiveRecord Added Behavior For MetaData
    ###################################################################

    include ActRecMetaData # module in lib/act_rec_meta_data.rb

    ###################################################################
    # ActiveRecord Added Behavior For Logging
    ###################################################################

    include ActRecLog # module in lib/act_rec_log.rb

    ###################################################################
    # ActiveRecord Added Behavior For Single Table Inheritance
    ###################################################################

    include CBRAINExtensions::ActiveRecord::SingleTableInheritance

    ###################################################################
    # ActiveRecord Added Behavior For Single Table Inheritance
    ###################################################################

    include CBRAINExtensions::ActiveRecord::AbstractModelMethods
    
    ###################################################################
    # Helpers to manage mass-assignable attributes.
    ###################################################################

    include CBRAINExtensions::ActiveRecord::MassAssignmentAuthorization


    ###################################################################
    # ActiveRecord Added Behavior For Data Typing
    ###################################################################

    cattr_accessor :cbrain_forced_attribute_encodings # cattr_accessor is from Rails

    # This directive adds an after_initalize() callback such that
    # attributes stored as :text in the schema are always reloaded
    # with a forced encoding. In a model:
    #
    #   force_attribute_encoding encoding_name, :att [, :att, ...]
    def self.force_text_attribute_encoding(encoding_name, *attlist)
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


    ###################################################################
    # ActiveRecord Added Behavior For Serialization
    ###################################################################

    # This directive is just like ActiveRecord's serialize directive,
    # but it makes sure that the hash will be reconstructed as
    # a HashWithIndifferentAccess ; it is meant to be backwards compatible
    # with old DBs where the records were saved as Hash, so it will
    # update them as they are reloaded using a after_initialize callback.
    def self.serialize_as_indifferent_hash(*attlist)
      attlist.each do |att|
        raise "Attribute '#{att}' not a symbol?!?" unless att.is_a?(Symbol)
        serialize att, BasicObject # we use this to record which attributes are to be indifferent.
        #serialize att
      end
      after_initialize :ensure_serialized_hash_are_indifferent
    end

    # Call this method in a :after_initialize callback, passsing it
    # a list of attributes that are supposed to be serialized hash
    # with indifferent access; if they are, nothing happens. If they
    # happen to be ordinary hashes, they'll be upgraded.
    def ensure_serialized_hash_are_indifferent #:nodoc:
      to_update = {}
      ser_attinfo = self.class.serialized_attributes
      attlist = ser_attinfo.keys.select { |att| ser_attinfo[att] == BasicObject }
      #attlist = ser_attinfo.keys
      attlist.each do |att|
        the_hash = read_attribute(att) # value of serialized attribute, as reconstructed by ActiveRecord
        if the_hash.is_a?(Hash) && ! the_hash.is_a?(HashWithIndifferentAccess)
  #puts_blue "Oh oh, must fix #{self.class.name}-#{self.id} -> #{att}"
          #new_hash = HashWithIndifferentAccess.new_from_hash_copying_default(the_hash)
          new_hash = the_hash.with_indifferent_access
          to_update[att] = new_hash
        end
      end

      unless to_update.empty?
        # Proper code that is supposed to update it once and for all in the DB:

        #self.update_attributes(to_update) # reactive once YAML dumping is fixed in Rails

        # Unfortunately, currently a HashWithIndifferentAccess is serialized EXACTLY as a Hash, so
        # it doesn't save any differently in the DB. To prevent unnecessary writes and rewrites of
        # always the same serialized Hash, we'll just update the attribute in memory instead:
        to_update.each do |att,val|
          write_attribute(att,val)
        end
      end

      true
    end

  end # class Base of ActiveRecord
  


  class Relation

    #####################################################################
    # ActiveRecord::Relation Added Behavior For Unstructured Data Fetches
    #####################################################################

    # Returns an array with just the first column of the
    # current relation. If an argument is given in +selected+,
    # then the relation is first modified with .select(selected)
    #
    #    User.where('login like "a%"').select(:login).raw_first_column
    #    => ["annie", "ahmed", "albator"]
    #
    #    User.where('login like "a%"').select(:id).raw_first_column
    #    => [3,4,7]
    #
    #    User.where('login like "a%"').raw_first_column(:id)
    #    => [3,4,7]
    #
    # This is basically a wrapper around the connection's
    # select_values() method (not to be confused with the
    # same method defined in ActiveRecord::Relation, which
    # does something completely different).
    def raw_first_column(selected = nil)
      modif = selected.present? ? self.select(selected) : self
      self.klass.connection.select_values(modif.to_sql)
    end

    # Returns an array of small arrays containing each record selected
    # by the current relation. If an argument is given in +selected+,
    # then the relation is first modified with .select(selected)
    #
    #    User.where('login like "a%"').select([:id,:login]).raw_rows
    #    => [[3, "annie"], [4, "ahmed"], [7, "albator"]]
    #
    #    User.where('login like "a%"').raw_rows([:id,:login])
    #    => [[3, "annie"], [4, "ahmed"], [7, "albator"]]
    #
    # This is basically a wrapper around the connection's
    # select_rows() method.
    def raw_rows(*args)
      selected = args.flatten
      modif = selected.present? ? self.select(selected) : self
      self.klass.connection.select_rows(modif.to_sql)
    end

    # Returns a new Relation where some clauses have been
    # removed; the arguments can be one or several attribute
    # names (which can be qualified with table names) and
    # any previous 'where' clauses that match one of these
    # attributes will be removed.
    #
    #   r = Author.joins(:book).where(:last => 'Austen').where('first like "J%"').where('books.title' like "Pride%")
    #   r.undo_where(:first, 'books.title') # => same as just:   last = 'Austen'
    #   r.undo_where('title')               # => does nothing (unless Author has also a :title !)
    #   r.undo_where('authors.last')        # => same as undo_where(:last)
    #
    # Note that if a previous where() restriction was a long string
    # with several subclauses, the entire string will be rejected
    # as soon as somewhere inside we can detect that at least one
    # subclause contained one of the attributes given in argument.
    #
    #
    #   r = Author.where([ "(id not in (?) or type = ?)", [2,3,4], 'AdminUser' ])
    #   r.undo_where(:type)   # => also rejects the restriction on :id !
    #
    # 
    def undo_where(*args)
      mymodel    = self.model_name.classify.constantize
      mytable    = mymodel.table_name
      without    = self.scoped # will create a new array for its where_values, but having the SAME elems!
      where_vals = without.where_values # this is what we need to prune

      to_reject = {} #  "tab1.col1" => true, "tab1.col2" => true etc...
      args.map do |colspec|  #  "col" or "table.col"
        raise "Invalid column specification \"#{colspec}\"." unless colspec.to_s =~ /^((\w+)\.)?(\w+)$/
        tab = Regexp.last_match[2].presence || mytable
        col = Regexp.last_match[3]
        to_reject["#{tab}.#{col}"] = true
      end

      #puts_yellow "TO REJ=#{to_reject.inspect}"
      return without if to_reject.empty? && ! block_given?

      where_vals.reject! do |node|
        if block_given? && yield(node) # custom rejection code ?
          #puts_red "Rejected by block"
          true
        elsif to_reject.empty? # optimize case of no args with block_given
          #puts_red "No args yet block"
          false
        elsif node.is_a?(Arel::Nodes::Equality)
          tab = node.left.relation.name rescue '???'
          col = node.left.name          rescue '???'
          #puts_red "EQ #{tab} #{col}"
          to_reject["#{tab}.#{col}"]
        elsif node.is_a?(String)   #     ((`table`.`col`) = 3) and col = 5
          #puts_red "STR #{node}"
          node.scan(/([\`\'\"]*(\w+)[\`\'\"]*\.)?[\`\'\"]*(\w+)[\`\'\"]*\s*(=|<|>|\sis\s|\snot\s)/).any? do |submatch|
            tab = submatch[1] || mytable   # note: numbering in submatch array is not like in Regexp.last_match !
            col = submatch[2]
            #puts_red "--> MATCH #{tab}.#{col}"
            to_reject["#{tab}.#{col}"]
          end
        else # unknown node type in Relation; TODO!
          #puts_red "UNKNOWN: #{node.class}"
          false
        end
      end

      without.where_values = where_vals
      without
    end

  end

end

