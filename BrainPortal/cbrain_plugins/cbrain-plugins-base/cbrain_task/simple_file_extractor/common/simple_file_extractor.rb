
#
# CBRAIN Project
#
# Copyright (C) 2008-2021
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

# Model code common to the Bourreau and Portal side for SimpleFileExtractor.
class CbrainTask::SimpleFileExtractor

  # In the params, the list of patterns is maintained as a hash:
  #   { "0" => "pat1", "1" => "pat2", etc }
  # This returns just the array of values, while preserving the ordering
  # that the keys encode:
  #   [ "pat1", "pat2" etc ]
  def patterns_as_array(pat_hash)
    keys      = pat_hash.keys.sort { |a,b| a.to_i <=> b.to_i }
    pat_array = keys.map { |i| pat_hash[i].presence }.compact
    pat_array
  end

  # This does the opposite of patterns_as_array; given
  # an array of patterns, returns a hash where the keys are
  # the index of the array
  def patterns_as_hash(pat_array)
    pat_hash = {}
    pat_array.each_with_index { |pat,i| pat_hash[i.to_s] = pat }
    pat_hash
  end

end

