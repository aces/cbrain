
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
    module RelationExtensions
      # ActiveRecord::Relation Added Behavior; remove a where() condition from an existing relation.
      module UndoWhere
      
        Revision_info=CbrainFileRevision[__FILE__] #:nodoc:
      
        # Returns a new Relation where some clauses have been
        # removed; the arguments can be one or several attribute
        # names (which can be qualified with table names).
        # Any previous 'where' clauses that match one of these
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
        #   r = Author.where([ "(id not in (?) or type = ?)", [2,3,4], 'AdminUser' ])
        #   r.undo_where(:type)   # => also rejects the restriction on :id !
        def undo_where(*args)
          mymodel    = self.model_name.classify.constantize
          mytable    = mymodel.table_name
          without    = clone # will create a new array for its where_values, but having the SAME elems!
          where_vals = without.where_values.clone # this is what we need to prune

          to_reject = {} #  "tab1.col1" => true, "tab1.col2" => true etc...
          args.map do |colspec|  #  "col" or "table.col"
            raise "Invalid column specification \"#{colspec}\"." unless
              colspec.to_s =~ /^(\`?(\w+)\`?\.)?\`?(\w+)\`?$/
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
              node.scan(/([\`\'\"]*(\w+)[\`\'\"]*\.)?[\`\'\"]*(\w+)[\`\'\"]*\s*(=|<|>|\sis\s|\snot\s|\sin\s|\slike\s)/i).any? do |submatch|
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
  end
end
