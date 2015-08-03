
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

require 'csv'

# Model for CSV file.
class CSVFile < TextFile

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  has_viewer :name => 'CSV Viewer', :partial  => :csv_file, :if  => :is_locally_synced?

  def self.pretty_type #:nodoc:
    "CSV File"
  end

  def self.file_name_pattern #:nodoc:
    /\.csv$/i
  end

  # Tries to guess and return the quote character
  # and the separator character for the content of the CSV file.
  # This method invokes the class method of the same name,
  # passing it the path the of the userfile's cache path. It
  # assumes the file has already been synchronized.
  #
  # Returns a triplet: [ quote_character, record_sepeaator, invalid_encoding ]
  # where invalid_encoding is true or false
  def guess_csv_quote_sep
    cache_path        = self.cache_full_path.to_s
    cb_error "File is not synchronized" unless self.is_locally_cached?
    self.class.guess_csv_quote_sep(cache_path)
  end

  # Tries to guess and return the quote character
  # and the separator character for a file +path+ on the local filesystem.
  #
  # Returns a triplet: [ quote_character, record_sepeaator, invalid_encoding ]
  # where invalid_encoding is true or false
  def self.guess_csv_quote_sep(path)
    quote_char_list  = ["\"","'","\x00"]
    col_sep_list     = [",",";",":","#","\t"," "]
    poss_combination = {}
    invalid_encoding = false

    escape_cache_path = path.bash_escape

    # Extract line delimiter. Sample output of 'file' command:
    # dos:  ASCII text, with CRLF line terminators
    # mac:  ASCII text, with CR line terminators
    # unix: ASCII text
    line_delim = ""
    IO.popen("file #{escape_cache_path} 2>/dev/null","r") do |fh|
      if fh.gets.index("with CR line")
        line_delim = "015" # octal for perl's -0 option : 015 is CR
      else
        line_delim = "012" # octal for perl's -0 option : 012 is LF
      end
    end

    # Get first 10 lines of the CSV document.
    csv_content = IO.popen("perl -0#{line_delim} -pe 'exit 0 if $. > 10' #{escape_cache_path} 2>/dev/null","r") { |fh| fh.read }

    quote_char_list.each do |qc|
      col_sep_list.each  do |cs|
        combinaison_key = [qc,cs]
        double_qc    = qc == "\"" ? "''" : "\"\""
        poss_combination[combinaison_key] = []
        begin
          CSV.parse(csv_content, :quote_char => qc, :col_sep => cs, :row_sep =>:auto) do |row|
            if row.size == 1
              poss_combination.delete(combinaison_key)
              break
            end
            need_to_quit = false
            row.each do |field|
              # Two '' or ""
              if field && field.index(double_qc)
                poss_combination.delete(combinaison_key)
                need_to_quit = true
                break
              end
            end
            break if need_to_quit
            poss_combination[combinaison_key] << row.size
          end
        rescue => exception
          if exception.is_a?(ArgumentError) && exception.message =~ /invalid byte sequence in/
            csv_content.encode!('UTF-16le', invalid: :replace, replace: '')
            csv_content.encode!('UTF-8')
            invalid_encoding = true
            retry
          else
            poss_combination.delete(combinaison_key)
          end
        end
      end
    end

    # Keep poss_combination which unique value
    poss_combination.each do |combinaison_key,count_by_line|
      count_by_line.uniq!
      poss_combination.delete(combinaison_key) if count_by_line.size != 1
    end

    # Sort solution usefull when we have multiple solution
    solutions = poss_combination.keys
    sorted_sols = solutions.sort do |ck1,ck2|
      q1,s1 = *ck1
      q2,s2 = *ck2
      compsep = col_sep_list.index(s1) <=> col_sep_list.index(s2)
      if compsep != 0
        compsep
      else
        quote_char_list.index(q1) <=> quote_char_list.index(q2)
      end
    end

    solution  = sorted_sols[0]
    solution << invalid_encoding if solution

    return solution
  end

  # Returns an array of array for the CSV file, representing
  # the rows and columns.
  def create_csv_array(quote, separator)
    cache_path = self.cache_full_path
    content    = self.class.read_file_content_as_UTF8(cache_path)
    return self.class.parse_file_content_as_csv(content, quote, separator)
  end

  # Utility method that chains together the behavior of
  # read_file_content_as_UTF8() and parse_file_content_as_csv().
  # This behaves like the instance method of the same name.
  def self.create_csv_array(path, quote, separator)
    content = read_file_content_as_UTF8(path)
    parse_file_content_as_csv(content, quote, separator)
  end

  # Invokes the parse() method of the CSV class to parse the
  # +content+ of a file (presumable read using the read_file_content_as_UTF8() method).
  def self.parse_file_content_as_csv(content, quote, separator)
    return CSV.parse(content, :quote_char => quote, :col_sep => separator, :row_sep => :auto)
  end

  # Reads the content of a file specified by path, forcing the encoding to be UTF8
  # Returns the transformed content.
  def self.read_file_content_as_UTF8(path)
    content = File.read(path)
    content.encode!('UTF-16le', invalid: :replace, replace: '')
    content.encode!('UTF-8')
    return content
  end

end
