
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


class CSVFile < TextFile

  Revision_info=CbrainFileRevision[__FILE__]

  has_viewer :partial  => "csv_file", :if  => :is_locally_synced?

  def self.pretty_type #:nodoc:
    "CSV File"
  end

  def self.file_name_pattern #:nodoc:
    /\.csv$/i
  end

  #A guesser for CSV file, try to define the quote character
  #and the seperator character 
  def guess_csv_quote_sep
    quote_char_list  = ["\"","'"]
    col_sep_list     = [",",";",":","#","\t"," "]
    poss_combination = {}

    cache_path = self.cache_full_path
    quote_char_list.each do |qc|
      col_sep_list.each  do |cs|
        combinaison_key = [qc,cs]
        double_qc    = qc == "\"" ? "''" : "\"\""
        poss_combination[combinaison_key] = []
        begin
          cnt = 0
          CSV.foreach(cache_path, :quote_char => qc, :col_sep => cs, :row_sep =>:auto) do |row|
            if row.size == 1
              poss_combination.delete(combinaison_key)
              break
            end
            need_to_quit = false
            row.each do |field|
              # Two '' or "" 
              if field.index(double_qc)
                poss_combination.delete(combinaison_key)
                need_to_quit = true
                break
              end
            end
            break if need_to_quit
            poss_combination[combinaison_key] << row.size
            cnt +=1
            break if cnt > 10
          end
        rescue
          poss_combination.delete(combinaison_key)
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
      
    solution = sorted_sols[0]

    return solution 
  end

  #Create an array of array for csv file,
  #You need to provide an array [quote, separator]
  def create_csv_array(csv_quote_sep)
    cache_path = self.cache_full_path
    file     = File.open(cache_path)
    contents = file.read
    array_of_array = CSV.parse(contents, :quote_char => csv_quote_sep[0], :col_sep => csv_quote_sep[1], :row_sep =>:auto) 
    return array_of_array
  end
  
end
