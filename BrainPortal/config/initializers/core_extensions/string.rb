
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
# CBRAIN String extensions
###################################################################
class String

  # Used by views for CbrainTasks to transform a
  # string such as "abc" or "abc[def]" into a path to a
  # variable inside the params[] hash, as in
  # "cbrain_task[params][abc]" or "cbrain_task[params][abc][def]"
  #
  # CBRAIN adds a similar method in the Symbol class.
  def to_la
    key = self
    if key =~ /^(\w+)/
      newcomp = "[" + Regexp.last_match[1] + "]"
      key = key.sub(/^(\w+)/,newcomp) # not sub!() !
    end
    "cbrain_task[params]#{key}"
  end

  # Used by views for CbrainTasks to transform a
  # string such as "abc" or "abc[def]" (representing
  # a path to a variable inside the params[] hash, as in
  # "cbrain_task[params][abc]" or "cbrain_task[params][abc][def]")
  # into the name of a pseudo accessor method for that variable.
  # This is also the name of the input field's HTML ID
  # attribute, used for error validations.
  #
  # CBRAIN adds a similar method in the Symbol class.
  def to_la_id
    self.to_la.gsub(/\W+/,"_").sub(/_+$/,"").sub(/^_+/,"")
  end

  # Considers self as a pattern to which substitutions
  # are to be applied; the substitutions are found in
  # self by recognizing keywords surreounded by
  # '{}' (curly braces) and those keywords are looked
  # up in the +keywords+ hash.
  #
  # Example:
  #
  #  mypat  = "abc{def}-{mach-3}{ext}"
  #  mykeys = {  :def => 'XYZ', 'mach-3' => 'fast', :ext => '.zip' }
  #  mypat.pattern_substitute( mykeys ) # return "abcXYZ-fast.zip"
  #
  # Note that keywords are limited to sequences of lowercase
  # characters and digits, like 'def', '3', or 'def23' or the same with
  # a number extension, like '4-34', 'def-23' and 'def23-3'.
  #
  # Options:
  #
  # :allow_unset, if true, allows substitution of an empty
  # string if a keyword is defined in the pattern but not
  # in the +keywords+ hash. Otherwise, an exception is raised.
  # :leave_unset, if true, leaves unsubstituded keywords as-is
  # in the string.
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

end

