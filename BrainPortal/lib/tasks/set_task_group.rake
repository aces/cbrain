
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

desc 'Initial setting of task groups (tasks unassigned to a group will be assigned to their owner\'s group).' 

namespace :db do
  task :set_task_group => :environment do |t|  
    all_tasks = CbrainTask.all
    puts "Checking groups for #{all_tasks.size} tasks."
    num_updates = 0
    all_tasks.each_with_index do |ct, i|
      if i % 500 == 0 && i > 0
        puts "Completed #{i} checks."
      end
      
      if ct.group_id.blank?
        ct.group_id = ct.user.own_group.id
        ct.save!
        num_updates += 1
      end
    end
    
    puts "\nDone!"
    puts "#{num_updates} tasks updated."
  end
end

