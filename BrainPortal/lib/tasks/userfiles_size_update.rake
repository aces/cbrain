desc 'Force the system to update the sizes of userfiles (optional min_size argument defines the minimum size of a userfile to be updated).' 

namespace :db do
  task :userfiles_size_update, :min_size, :needs  => :environment do |t, args|  
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
