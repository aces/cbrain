
#
# CBRAIN Project
#
# Validation code for brainportal
#
# Original author: Pierre Rioux
#
# $Id$
#

puts "C> Verifying configuration variables..."

Needed_Constants = %w( Filevault_dir DataProviderCache_dir )

# Constants
Needed_Constants.each do |c|
  unless CBRAIN.const_defined?(c)
    raise "Configuration error: the CBRAIN constant '#{c}' is not defined! Check 'config_portal.rb'."
  end
end
  
# Run-time checks
unless File.directory?(CBRAIN::Filevault_dir)
  raise "CBRAIN configuration error: file vault '#{CBRAIN::Filevault_dir}' does not exist!"
end
unless File.directory?(CBRAIN::DataProviderCache_dir)
  raise "CBRAIN configuration error: data provider cache dir '#{CBRAIN::DataProviderCache_dir}' does not exist!"
end



puts "C> Making sure all providers have proper cache subdirectories..."

# Creating cache dir for Data Providers
begin
  DataProvider.all.each do |p|
    begin
      p.mkdir_cache_providerdir
    rescue => e
      unless e.to_s.match(/No caching in this provider/i)
        raise e
      end
    end
  end
rescue => error
  if error.to_s.match(/Mysql::Error.*Table.*data_providers.*doesn't exist/i)
    puts "... skipped: DataProviders table doesn't exist yet. It's likely this system is new and the migrations have not been run yet."
  else
    raise error
  end
end
