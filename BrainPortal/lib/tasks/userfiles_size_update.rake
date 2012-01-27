
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

desc 'Force the system to update the sizes of userfiles (optional min_size argument defines the minimum size of a userfile to be updated).' 

namespace :db do
  task :userfiles_size_update, [:min_size] => :environment do |t, args|  
    args.with_defaults(:min_size => 2_000_000_000)  
    min_size = args.min_size.to_i
    Userfile.all(:conditions  => ["size > ?", min_size]).each do |u|
      puts "Recalculating size for #{u.name}."
      begin
        u.set_size!
      rescue => e
        puts "Could not recalculate size for #{u.name}: #{e.message}"
      end
    end
    puts "\nDone!"
  end
end

