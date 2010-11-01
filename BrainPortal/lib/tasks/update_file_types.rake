namespace :db do
  desc "Update file types on all userfiles (set report to 'true' to get update report without actually performing the update)"
  task :update_file_types , :report, :needs  => :environment do |t, args|  
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
