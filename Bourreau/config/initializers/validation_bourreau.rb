
#
# CBRAIN Project
#
# Validation code for Bourreau
#
# Original author: Pierre Rioux
#
# $Id$
#

puts "C> Verifying configuration variables..."

Needed_Constants = %w(
                       Filevault_dir DataProviderCache_dir
                       DRMAA_sharedir Quarantine_dir CIVET_dir
                       BOURREAU_CLUSTER_NAME CLUSTER_TYPE DEFAULT_QUEUE
                     )

# Constants
Needed_Constants.each do |c|
  unless CBRAIN.const_defined?(c)
    raise "Configuration error: the CBRAIN constant '#{c}' is not defined! Check 'config_bourreau.rb'."
  end
end
  
# Run-time checks
unless File.directory?(CBRAIN::Filevault_dir)
  raise "CBRAIN configuration error: file vault '#{CBRAIN::Filevault_dir}' does not exist!"
end
unless File.directory?(CBRAIN::DataProviderCache_dir)
  raise "CBRAIN configuration error: data provider cache dir '#{CBRAIN::DataProviderCache_dir}' does not exist!"
end
unless File.directory?(CBRAIN::DRMAA_sharedir)
  raise "CBRAIN configuration error: grid work directory '#{CBRAIN::DRMAA_sharedir}' does not exist!"
end
unless File.directory?(CBRAIN::Quarantine_dir)
  raise "CBRAIN configuration error: quarantine dir '#{CBRAIN::Quarantine_dir}' does not exist!"
end
unless File.directory?(CBRAIN::CIVET_dir)
  raise "CBRAIN configuration error: civet code dir '#{CBRAIN::CIVET_dir}' does not exist!"
end

if CBRAIN::BOURREAU_CLUSTER_NAME.empty? || CBRAIN::BOURREAU_CLUSTER_NAME == "nameit"
  raise "CBRAIN configuration error: this Bourreau has not been given a name!"
end



puts "C> Making sure all providers have proper cache subdirectories..."

# Creating cache dir for Data Providers
DataProvider.all.each do |p|
  begin
    p.mkdir_cache_providerdir
  rescue => e
    unless e.to_s.match(/No caching in this provider/i)
      raise e
    end
  end
end



puts "C> Loading cluster management SCIR layers..."

# Load the proper class for interacting with the cluster
case CBRAIN::CLUSTER_TYPE
  when "SGE"
    require 'scir_sge.rb'
  when "PBS"
    require 'scir_pbs.rb'
  when "UNIX"
    require 'scir_local.rb'
  else
    raise "CBRAIN configuration error: CLUSTER_TYPE is set to unknown value #{CBRAIN::CLUSTER_TYPE}!"
end

