
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
        next nil
      end

      baclogger = Logger.new(
        "#{Rails.root}/log/#{worker_name}.log",
        100, 1_048_576,  # up to 100 files, 1mb each
      )
      baclogger.formatter = Proc.new do |severity, time, progname, msg|
        sprintf("%s %s %s\n",time.strftime("%Y-%m-%d %H:%M:%S"),severity,msg)
      end
      baclogger.level = 'debug'

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


