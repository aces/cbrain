#
# CBRAIN Project
#
# Portal Runtime system checks
#
# Original author: Nicolas Kassis
#
# $Id$
#



require 'checker.rb'

class PortalSystemCheck < Checker
  
  RevisionInfo="$Id$"
  #Checks for pending migrations, stops the boot if it detects a problem. Must be run first
  def self.check_001_if_pending_database_migrations
    #-----------------------------------------------------------------------------
    puts "C> Checking for pending migrations..."
    #-----------------------------------------------------------------------------
    

    if defined? ActiveRecord
      pending_migrations = ActiveRecord::Migrator.new(:up, 'db/migrate').pending_migrations
      if pending_migrations.any?
        puts "C> \t- You have #{pending_migrations.size} pending migrations:"
        pending_migrations.each do |pending_migration|
        puts "C> \t\t- %4d %s" % [pending_migration.version, pending_migration.name]
        end
        puts "C> \t- Please run \"rake db:migrate\" to update your database then try again."
        Kernel.exit
        
      end
    end
  end
    
  def self.check_002_database_sanity
    #----------------------------------------------------------------------------
    puts "C> Checking if the BrainPortal database needs a sanity check"
    #----------------------------------------------------------------------------
    unless PortalSanityCheck.done? 
       puts "C> - Error: You must check the sanity of the model. Pleasae run rake db:sanity:check" 
       Kernel.exit
    end
  end

  def self.ensure_003_portal_RemoteResourceId_constant_is_set
    #-----------------------------------------------------------------------------
    puts "C> Ensure that the CBRAIN::RemoteResourceId constant is set"
    #-----------------------------------------------------------------------------
    #Assigning this constant here because constant cannot be assigned dynamically inside a method like run_validation 
    dp_cache_md5 = DataProvider.cache_md5
    brainportal  = BrainPortal.find(:first,
                                    :conditions => { :cache_md5 => dp_cache_md5 })
    if brainportal
      
      CBRAIN.const_set("SelfRemoteResourceId",brainportal.id)
      
    else
      #----------------------------------------------------------------------------------------
      puts "C> - BrainPortal not registered in database, please run 'rake db:sanity:check"
      #----------------------------------------------------------------------------------------
      Kernel.exit(1)
    end
  end

  def self.check_configuration_variables
    #-----------------------------------------------------------------------------
    puts "C> Verifying configuration variables..."
    #-----------------------------------------------------------------------------
  
    needed_Constants = %w( DataProviderCache_dir )
    
    # Constants
    needed_Constants.each do |c|
      unless CBRAIN.const_defined?(c)
        raise "Configuration error: the CBRAIN constant '#{c}' is not defined!\n" +
          "Check 'config_portal.rb' (and compare it to 'config_portal.rb.TEMPLATE')."
      end
    end
    
    # Run-time checks
    unless File.directory?(CBRAIN::DataProviderCache_dir)
      raise "CBRAIN configuration error: Data Provider cache dir '#{CBRAIN::DataProviderCache_dir}' does not exist!"
    end
    
  end
  
  def self.check_data_provider_cache
    #-----------------------------------------------------------------------------
    puts "C> Checking to see if Data Provider caches need wiping..."
    #-----------------------------------------------------------------------------
    dp_init_rev    = DataProvider.cache_revision_of_last_init  # will be "0" if unknown
    dp_current_rev = DataProvider.revision_info.svn_id_rev
    raise "Serious Internal Error: I cannot get a numeric SVN revision number for DataProvider?!?" unless
      dp_current_rev && dp_current_rev =~ /^\d+/
    if dp_init_rev.to_i <= 659 # Before Pierre's upgrade
      puts "C> \t- Data Provider Caches are being wiped (Rev: #{dp_init_rev} vs #{dp_current_rev})..."
      puts "C> \t- WARNING: This could take a long time so you should not"
      puts "C> \t  start another instance of this Rails application."
      Dir.chdir(DataProvider.cache_rootdir) do
        Dir.foreach(".") do |entry|
          next unless File.directory?(entry) && entry !~ /^\./
          puts "C> \t\t- Removing old cache subdirectory '#{entry}' ..."
          FileUtils.remove_entry(entry, true) rescue true
        end
      end
      puts "C> \t- Synchronization objects are being wiped..."
      synclist = SyncStatus.find(:all, :conditions => { :remote_resource_id => CBRAIN::SelfRemoteResourceId })
      synclist.each do |ss|
        ss.destroy rescue true
      end
      puts "C> \t- Re-recording DataProvider revision number in cache."
      DataProvider.cache_revision_of_last_init(:force)
      puts "C> \t- Done."
    end
  end

  def self.check_data_provider_cache_subdirs
    #-----------------------------------------------------------------------------
    puts "C> Ensuring that all Data Providers have proper cache subdirectories..."
    #-----------------------------------------------------------------------------
    
    # Creating cache dir for Data Providers
    DataProvider.all.each do |p|
      begin
        p.mkdir_cache_providerdir
        puts "C> \t- Data Provider '#{p.name}': OK."
      rescue => e
        unless e.to_s.match(/No caching in this provider/i)
          raise e
        end
        puts "C> \t- Data Provider '#{p.name}': no need."
      end
    end
    
    
  end
  
  def self.start_bourreau_ssh_tunnels
    #-----------------------------------------------------------------------------
    puts "C> Starting SSH control channels and tunnels to each Bourreau, if necessary..."
    #-----------------------------------------------------------------------------
    
    Bourreau.all.each do |bourreau|
      name = bourreau.name
      if (bourreau.has_remote_control_info? rescue false)
        if bourreau.online
          tunnels_ok = bourreau.start_tunnels
          puts "C> \t- Bourreau '#{name}' channels " + (tunnels_ok ? 'started.' : 'NOT started.')
        else
          puts "C> \t- Bourreau '#{name}' not marked as 'online'."
        end
      else
        puts "C> \t- Bourreau '#{name}' not configured for remote control."
      end
    end
  end  


  #-----------------------------------------------------------------------------
  # :RESCUE: For the cases when the Rails application is started as part of
  # a DB migration.
  #-----------------------------------------------------------------------------

      
  #   if error.to_s.match(/Mysql::Error.*Table.*doesn't exist/i)
  #     puts "Skipping validation:\n\t- Database table doesn't exist yet. It's likely this system is new and the migrations have not been run yet."
  #   elsif error.to_s.match(/Mysql::Error: Unknown column/i)
  #     puts "Skipping validation:\n\t- Some database table is missing a column. It's likely that migrations aren't up to date yet."
  #   elsif error.to_s.match(/Unknown database/i)
  #     puts "Skipping validation:\n\t- System database doesn't exist yet. It's likely this system is new and the migrations have not been run yet."
  #   else
  #     raise
  #   end

  # end # :RESCUE:

end 
