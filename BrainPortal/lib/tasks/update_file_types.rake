namespace :db do
  desc "Update file types on all userfiles"
  task :update_file_types => :environment do
    stats = {}
  
    Userfile.all.each do |file|
      if file.suggested_file_type && file.class != file.suggested_file_type
        file.type = file.suggested_file_type.name
        file.save!
        stats[file.type] ||= 0
        stats[file.type] += 1
      end
    end
    
    unless stats.empty?
      puts "Update statistics:"
      stats.each do |k, v|
        puts "#{v} userfiles updated to type '#{k}'"
      end
    end
  end
end
