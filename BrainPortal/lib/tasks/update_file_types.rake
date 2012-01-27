
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

namespace :db do
  desc "Update file types on all userfiles (set report to 'true' to get update report without actually performing the update)"
  task :update_file_types , [:report] => :environment do |t, args|  
    args.with_defaults(:report => "false")
    if args.report.to_s.downcase == "true"  
      report = true
    else
      report = false
    end
    stats = {}
  
    Userfile.all.each do |file|
      if file.suggested_file_type && file.class != file.suggested_file_type
        from_type = file.type
        to_type   = file.suggested_file_type.name
        unless report
          file.type = to_type
          file.save!
        end
        stats[from_type]          ||= {}
        stats[from_type][to_type] ||= 0
        stats[from_type][to_type] += 1
      end
    end
    
    unless stats.empty?
      if report
        puts "The following updates would be made if this task were run:"
      else
        puts "Update statistics:"
      end
      stats.each do |frt, v|
        v.each do |tot, cnt|
          puts "#{cnt} userfiles #{"would be " if report }converted from '#{frt}' to '#{tot}'."
        end
      end
      puts "\nNOTE: the update was NOT actually performed." if report
    end
  end
end

