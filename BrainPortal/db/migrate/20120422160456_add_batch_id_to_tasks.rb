class AddBatchIdToTasks < ActiveRecord::Migration
  def self.up
    add_column    :cbrain_tasks, :batch_id, :integer, :after => :type
    add_index     :cbrain_tasks, :batch_id

    puts "Adjusting tasks batch IDs... this may take some time."

    no_lt = CbrainTask.real_tasks.where(:launch_time => nil)
    puts " -> Tasks with no launch_time : #{no_lt.count}"
    no_lt.all.each do |t|
      t.update_attribute(:launch_time, t.created_at)
    end

    tot = CbrainTask.real_tasks.count
    puts " -> All tasks: #{tot}"
    
    lts = CbrainTask.connection.select_values(CbrainTask.real_tasks.select("distinct(launch_time)").to_sql)
    puts " -> Number of batches: #{lts.size}"

    tsk_count = 0
    lts.each_with_index do |lt,idx|
      tasks      = CbrainTask.real_tasks.where(:launch_time => lt)
      cnt        = tasks.count
      tsk_count += cnt
      if idx+1 % 50 == 0 || cnt >= 100
        puts "   -> Batch #{idx+1}/#{lts.size} with #{cnt} tasks (cumul #{tsk_count}/#{tot})"
      end
      first_task = tasks.order([:rank, :level, :created_at, :id]).first
      tasks.update_all(:batch_id => first_task.id)
    end

    puts "All done."

  end

  def self.down
    remove_index  :cbrain_tasks, :batch_id
    remove_column :cbrain_tasks, :batch_id
  end
end
