desc 'Initial setting of userfiles tree level.' 

namespace :db do
  task :set_userfile_level, :needs  => :environment do |t|  
    root_files = Userfile.all(:conditions  => {:parent_id  => nil})
    all_files = Userfile.all(:conditions  => {:level  => nil})
    puts "Found #{root_files.size} root userfiles."
    puts "Found #{all_files.size} userfiles with unset levels."
    root_files.each do |file|
      file.set_level!
    end
    
    all_files = Userfile.all(:conditions  => {:level  => nil})
    
    if all_files.size > 0
      puts "#{all_files.size} userfiles could not have their levels set."
      puts "There are likely some dead links in the tree structure."
      puts "Setting their levels to 0..."
      all_files.each do |file|
        file.level = 0
        file.save!
      end
    end
    puts "All files now have set levels."
  end
end