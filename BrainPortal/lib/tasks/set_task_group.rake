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
