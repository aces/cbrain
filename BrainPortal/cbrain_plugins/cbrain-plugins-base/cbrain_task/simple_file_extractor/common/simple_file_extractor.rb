
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

  # In the params, patterns, replacement path, folder flags are maintained as a hash:
  #   #   { "0" => ["*/pat1"],  "1" => "*/pat2", etc }, {"0": "subfolder1", "1" => nil...}
  #   #   { "0" => ["*/pat1"],  "1" => "*/pat2", etc }, {"0": "subfolder1", "1" => nil...}
  # This method convert three hashes just the array of values, while preserving the ordering
  # that the keys encode, and skipping empty rows:
  #   [ ["pat1", "pat2"], etc ]
  # Usually some indexes with no info in either category
  def patterns_as_arrays(pat_hash, repl_hash, fold_hash)
    keys      = pat_hash.keys.sort_by(&:to_i)
    pat_array = keys.map do |i|
      [
        pat_hash[i]&.strip.presence,
        repl_hash[i]&.strip.presence,
        fold_hash[i]
      ]
    end.select { |x, y, z| x || y || z == "1" } # filter out blank rows
    return pat_array.transpose
  end

  # This allows perform the opposite of patterns_as_array; given
  # an array of patterns, path, or flags , returns array of hash where the keys are
  # the index of the array
  # Hash it returns has with array indexes as values (stringifierd)
  #
  def array_to_hash(arr)
    hsh = arr.map.with_index { |pat, i| [i.to_s, pat] }.to_h
    hsh
  end

  # best effort mapping of a glob pattern to regex (with groups)
  # https://stackoverflow.com/questions/1307712/how-to-convert-glob-to-regular-expression
  def glob_to_regex(glob)
    escaped = ''
    i = 0
    while i < glob.length
      char = glob[i]

      case char
      when '*'
        # Check for ** (recursive)
        if glob[i, 2] == '**'
          escaped << '(.+?)'  # non-greedy match across directories
          i += 1
        else
          escaped << '([^/]+)' # * matches a single path segment
        end
      when '?'
        escaped << '(.)'
      when '['
        # Copy character class literally until closing ]
        j = i + 1
        while j < glob.length && glob[j] != ']'
          j += 1
        end
        char_class = glob[i..j]  # include the closing ]
        escaped << char_class
        i = j
      when '{'
        # Convert {a,b,c} → (a|b|c)
        j = i + 1
        brace_content = ''
        depth = 1
        while j < glob.length && depth > 0
          if glob[j] == '{'
            depth += 1
          elsif glob[j] == '}'
            depth -= 1
          end
          brace_content << glob[j] if depth > 0
          j += 1
        end
        alternatives = brace_content.split(',').map { |x| Regexp.escape(x) }.join('|')
        escaped << "(#{alternatives})"
        i = j - 1
      else
        escaped << Regexp.escape(char)  # escape other character
      end
      i += 1
    end
    Regexp.new("\\A#{escaped}\\z")
  end

end
