
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
  module StringExtensions #:nodoc:

    # CBRAIN string utilities.
    module Utilities

      Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

      # This utility method escapes properly any string such that
      # it becomes a literal in a bash command; the string returned
      # will include some surrounding single quotes if necessary.
      #
      #   puts "".bash_escape                     => ''
      #   puts "abcd".bash_escape                 => abcd
      #   puts "Mike O'Connor".bash_escape        => 'Mike O'\'Connor
      #   puts "abcd".bash_escape(true)           => 'abcd'
      #   puts "Mike O'Connor".bash_escape(true)  => 'Mike O'\''Connor'
      #
      def bash_escape(always_quote = false, no_empty = false)
        return (no_empty ? "" : "''") if     self == ''
        return self                   if     !always_quote && self =~ %r{\A[0-9a-zA-Z_.,:/=@+-]+\z}
        return "'#{self}'"            unless self.index("'")
        comps = self.split(/('+)/)
        comps.each_with_index do |comp,idx|
          comps[idx] = idx % 2 == 0 ? comp.bash_escape(always_quote, true) : ("\\'" * comp.size)
        end
        comps.join
      end

      # This method is mostly used on text file content;
      # it attempts to detect and validate different original
      # encodings then record it in UTF8. The returned value
      # is the UTF version of the string. Returns nil if
      # no valid encoding was found for the original string.
      def text_file_content_to_utf8
        orig_encoding = self.encoding
        [ 'UTF-8', 'ISO-8859-1', 'US-ASCII', 'ASCII-8BIT', orig_encoding ].each do |en|
          return self.encode('UTF-8') if self.valid_encoding?
          self.force_encoding(en)
        end
        nil
      ensure
        self.force_encoding(orig_encoding)
      end

      # Used by views for CbrainTasks to transform strings such as these:
      #
      #    "abc", "abc[def]",
      #
      # into paths to a variables inside the params[] hash, as in:
      #
      #   "cbrain_task[params][abc]", "cbrain_task[params][abc][xyz]"
      #
      # CBRAIN adds a similar method in the Symbol class.
      #
      # This can be used to build custom input fields for CbrainTask's
      # params hashes, although there are already a nice collection of
      # helper methods defined in CbrainTaskFormBuilder .
      def to_la
        key = self
        if key =~ /\A(\w+)/
          newcomp = "[" + Regexp.last_match[1] + "]"
          key = key.sub(/\A(\w+)/,newcomp) # not sub!() !
        end
        "cbrain_task[params]#{key}"
      end

      # Used by views for CbrainTasks to transform strings (a.k.a. +paramspaths+)
      # into names of a pseudo accessor method for that variable, as in:
      #
      #    "abc"      => "cbrain_task_BRA_params_KET__BRA_abc_KET_",
      #    "abc"      => "cbrain_task_BRA_params_KET__BRA_abc_KET_",
      #    "abc[def]" => "cbrain_task_BRA_params_KET__BRA_abc_KET__BRA_def_KET_"
      #
      # The string is first run through .to_la(), which adds the constant prefix
      # "cbrain_task[params][abc]", then the brackets are tranformed into identifier
      # friendly characters.
      #
      # This is also the name of the input field's HTML ID
      # attribute, used for error validations.
      #
      # There is a similar method in the Symbol class, which just calls
      # this method here and then symbolize the results.
      #
      # This can be used to give IDs to input fields for CbrainTask's
      # params hashes, although there are already a nice collection of
      # helper methods defined in CbrainTaskFormBuilder .
      def to_la_id
        self.to_la.gsub('[','_BRA_').gsub(']','_KET_')
      end

      # Does the reverse of to_la_id().
      def from_la_id
        self.gsub('_BRA_','[').gsub('_KET_',']').gsub('cbrain_task[params]','').sub(/^\[(\w+)\]/,'\1')
      end

      # Considers self as a pattern to which substitutions
      # are to be applied; the substitutions are found in
      # self by recognizing keywords surreounded by
      # '{}' (curly braces) and those keywords are looked
      # up in the +keywords+ hash.
      #
      # ==== Example:
      #
      #   mypat  = "abc{def}-{mach-3}{ext}"
      #   mykeys = {  :def => 'XYZ', 'mach-3' => 'fast', :ext => '.zip' }
      #   mypat.pattern_substitute( mykeys ) # return "abcXYZ-fast.zip"
      #
      # Note that keywords are limited to sequences of lowercase
      # characters and digits, like 'def', '3', or 'def23' or the same with
      # a number extension, like '4-34', 'def-23' and 'def23-3'.
      #
      # ==== Options:
      #
      # [:allow_unset] if true, allows substitution of an empty
      #                string if a keyword is defined in the pattern but not
      #                in the +keywords+ hash. Otherwise, an exception is raised.
      #
      # [:leave_unset] if true, leaves unsubstituded keywords as-is
      #                in the string.
      #
      def pattern_substitute(keywords, options = {})
        pat_comps = self.split(/(\{(?:[a-z0-9_]+(?:-\d+)?)\})/i)
        final = []
        pat_comps.each_with_index do |comp,i|
          if i.even?
            final << comp
          else
            barecomp = comp.tr("{}","")
            val = keywords[barecomp.downcase] || keywords[barecomp.downcase.to_sym]
            if val.nil?
              cb_error "Cannot find value for keyword '{#{barecomp.downcase}}'." if options[:leave_unset].blank? && options[:allow_unset].blank?
              val = comp                                                         if options[:leave_unset].present?
            end
            final << val.to_s
          end
        end
        final.join
      end

      # Check if a String contains the textual representation of an integer.
      # Useful for form validation.
      def is_an_integer?
        Integer(self) && true rescue false
      end

      # Check if a String contains the textual representation of a float.
      # Useful for form validation.
      def is_a_float?
        Float(self) && true rescue false
      end

    end
  end
end

