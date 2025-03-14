
#
# Rake tasks for launching Workers for Background Activity tasks
#

namespace :cbrain do
  namespace :background do
    namespace :worker do

    ##########################################################################
    desc "Start a BackgroundActivityWorker (blocking)"
    ##########################################################################
    task :start => [ :environment ] do

      worker_name = 'RakePortalActivity'
      num_workers = ::Rails.env == 'production' ? 3 : 1

      worker_pool = WorkerPool.find_pool(BackgroundActivityWorker)
      if worker_pool.workers.size > 0
        puts "BackgroundActivityWorkers already exist: PID=#{worker_pool.workers.map(&:pid).join(", ")}"
        break
      end

      baclogger = Log4r::Logger.new(worker_name)
      outputter = Log4r::FileOutputter.new('background_activity_outputter',
                    :filename  => "#{Rails.root}/log/#{worker_name}.log",
                    :formatter => Log4r::PatternFormatter.new(:pattern => "%d %l %m")
                    )
      baclogger.add(outputter)
      baclogger.level = Log4r::DEBUG

      worker_pool = WorkerPool.create_or_find_pool(BackgroundActivityWorker,
         num_workers, # number of instances
         { :name           => worker_name,
           :check_interval => 5,
           :worker_log     => baclogger
         }
      )

      puts "\n\n\n======================================================"
      puts "Background Activity Worker started: PID=#{worker_pool.workers.map(&:pid).join(", ")}"
      puts "Hit CTRL-C quit this task, and the worker will stop after a few seconds"

      stop = false;
      Signal.trap("TERM") { stop = true }
      Signal.trap("INT")  { stop = true }
      system "tail -f #{Rails.root}/log/#{worker_name}.log"
      while ! stop # amazingly frightening infinite loop
        sleep 1
      end

    end

    end # namespace worker
  end # namespace background
end # namespace cbrain


