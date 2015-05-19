
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

  #A guesser for CSV file, try to define the quote character
  #and the seperator character
  def guess_csv_quote_sep
    quote_char_list  = ["\"","'","\x00"]
    col_sep_list     = [",",";",":","#","\t"," "]
    poss_combination = {}
    invalid_encoding = false

    cache_path        = self.cache_full_path.to_s
    escape_cache_path = cache_path.bash_escape

    # Extract line delimiter. Sample output of 'file' command:
    # dos:  ASCII text, with CRLF line terminators
    # mac:  ASCII text, with CR line terminators
    # unix: ASCII text
    line_delim = ""
    IO.popen("file #{escape_cache_path}","r") do |fh|
      if fh.gets.index("with CR line")
        line_delim = "015" # octal for perl's -0 option : 015 is CR
      else
        line_delim = "012" # octal for perl's -0 option : 012 is LF
      end
    end

    # Get first 10 lines of the CSV document.
    csv_content = IO.popen("perl -0#{line_delim} -pe 'exit 0 if $. > 10' #{escape_cache_path}","r") { |fh| fh.read }

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

  #Create an array of array for csv file,
  def create_csv_array(quote,separator)
    cache_path = self.cache_full_path
    file       = File.read(cache_path)
    file.encode!('UTF-16le', invalid: :replace, replace: '')
    file.encode!('UTF-8')

    return CSV.parse(file, :quote_char => quote, :col_sep => separator, :row_sep => :auto)
  end

end
