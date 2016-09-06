
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

# This module implements useful methods for
# managing a directory tree where the files are
# stored in a subdirectory structure such as
#
#   root/01/02/03/file1
#   root/01/02/04/file2
#
# etc.
module NumericalSubdirTree

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def self.included(includer) #:nodoc:
    includer.class_eval do
      extend NumericalSubdirTreeClassMethods
    end
  end

  module NumericalSubdirTreeClassMethods

    # Returns a relative directory path with three components
    # based on the +number+; the path will be in format
    #     "ab/cd/ef"
    # where +ab+, +cd+ et +ef+ components are two digits
    # long extracted directly from +number+. Examples:
    #
    #    Number      Path
    #    ----------- --------
    #    0           00/00/00
    #    5           00/00/05
    #    100         00/01/00
    #    2345        00/23/45
    #    462292      46/22/92
    #    1462292    146/22/92
    #
    # The path is returned as an array of string
    # components, as in
    #
    #    [ "146", "22","92" ]
    def numerical_subdir_tree_components(number)
      cb_error "Did not get a proper numeric ID? Got: '#{number.inspect}'." unless number.is_a?(Integer)
      sid = "000000" + number.to_s
      unless sid =~ /\A0*(\d*\d\d)(\d\d)(\d\d)\z/
        raise "Can't create subpath for '#{number}'."
      end
      lower  = Regexp.last_match[1] # 123456 -> 12
      middle = Regexp.last_match[2] # 123456 -> 34
      upper  = Regexp.last_match[3] # 123456 -> 56
      [ lower, middle, upper ]
    end

    # Make, if needed, the three subdirectory levels for a number.
    # For instance, when called with 344577 :
    #
    #     mkdir "rootpath/34"
    #     mkdir "rootpath/34/45"
    #     mkdir "rootpath/34/45/77"
    def mkdir_numerical_subdir_tree_components(rootpath, number)
      threelevels = numerical_subdir_tree_components(number)
      level0 = Pathname.new(rootpath)
      level1 = level0                 + threelevels[0]
      level2 = level1                 + threelevels[1]
      level3 = level2                 + threelevels[2]
      unless File.directory?(level1.to_s)
        Dir.mkdir(level1.to_s) rescue true
      end
      unless File.directory?(level2.to_s)
        Dir.mkdir(level2.to_s) rescue true
      end
      unless File.directory?(level3.to_s)
        Dir.mkdir(level3.to_s) rescue true
      end
      true
    end

    # Removes the subdirectory tree for number.
    # Components are removed in reverse order,
    # and stops as soon as a rmdir fails. This is
    # so you can safely invoke it to clean unused
    # parts of a tree only, while leaving the active
    # parts intact. For instance, if the tree looks
    # like this (and only this):
    #
    #   rootpath/01/23/45/
    #   rootpath/01/23/46/datafile
    #   rootpath/02/55/21/
    #   rootpath/02/99/32/datafile
    #
    # then calling this method on number 12345 will
    # remove the "45" subdirectory only, while calling
    # the method on number 25521 will remove both
    # the "21" and the "55" subdirectory (and leave "02").
    #
    # Returns the number of components erased.
    def rmdir_numerical_subdir_tree_components(rootpath, number)
      threelevels = numerical_subdir_tree_components(number)
      level0 = Pathname.new(rootpath)
      level1 = level0                 + threelevels[0]
      level2 = level1                 + threelevels[1]
      level3 = level2                 + threelevels[2]
      erased = 0
      erased += ((Dir.rmdir(level3.to_s) rescue nil) ? 1 : 0)
      erased += ((Dir.rmdir(level2.to_s) rescue nil) ? 1 : 0) if erased == 1
      erased += ((Dir.rmdir(level1.to_s) rescue nil) ? 1 : 0) if erased == 2
      erased
    end

  end

end

