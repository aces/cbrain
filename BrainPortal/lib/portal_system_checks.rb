#
# CBRAIN Project
#
# Portal Runtime system checks
#
# Original author: Nicolas Kassis
#
# $Id$
#

class PortalSystemChecks < CbrainChecker
  
  Revision_info="$Id$"



  #Checks for pending migrations, stops the boot if it detects a problem. Must be run first
  def self.a010_check_if_pending_database_migrations

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
        puts "C> \t- Please run \"rake db:migrate RAILS_ENV=#{ENV['RAILS_ENV']}\" to update"
        puts "C> \t  your database then try again."
        puts "C> \t- Note:  You can skip all CBRAIN validations by temporarily setting the\n"
        puts "C> \t         environment variable 'CBRAIN_SKIP_VALIDATIONS' to '1'.\n"
        Kernel.exit(1)
      end
    end
  end
    


  def self.a020_check_database_sanity

    #----------------------------------------------------------------------------
    puts "C> Checking if the BrainPortal database needs a sanity check..."
    #----------------------------------------------------------------------------

    unless PortalSanityChecks.done? 
      puts "C> \t- Error: You must check the sanity of the models. Please run this\n"
      puts "C> \t         command: 'rake db:sanity:check RAILS_ENV=#{ENV['RAILS_ENV']}'." 
      puts "C> \t- Note:  You can skip all CBRAIN validations by temporarily setting the\n"
      puts "C> \t         environment variable 'CBRAIN_SKIP_VALIDATIONS' to '1'.\n"
      Kernel.exit(1)
    end
  end



  def self.a030_check_configuration_variables

    #-----------------------------------------------------------------------------
    puts "C> Verifying configuration variables..."
    #-----------------------------------------------------------------------------
  
    needed_Constants = %w(
                       Site_URL
                       DataProviderCache_dir
                       DataProviderCache_RevNeeded
                       DataProvider_IgnorePatterns
                     )
    
    # Constants
    needed_Constants.each do |c|
      unless CBRAIN.const_defined?(c)
        raise "Configuration error: the CBRAIN constant '#{c}' is not defined!\n" +
              "Check 'config_portal.rb' (and compare it to 'config_portal.rb.TEMPLATE')."
      end
    end
    
    # Run-time checks
    unless File.directory?(CBRAIN::DataProviderCache_dir)
      raise "CBRAIN configuration error: Data Provider cache directory '#{CBRAIN::DataProviderCache_dir}' does not exist!"
    end

    raise "CBRAIN configuration error: 'DataProvider_IgnorePatterns' is not an array!" unless
      CBRAIN::DataProvider_IgnorePatterns.is_a?(Array)

    CBRAIN::DataProvider_IgnorePatterns.each do |pattern|
      raise "Configuration error: the pattern '#{pattern}' in 'DataProvider_IgnorePatterns' is not acceptable." if
        pattern.blank? ||
        pattern == "*" ||
        ! pattern.is_a?(String) ||
        pattern =~ /\*\*/ ||
        pattern =~ /\// ||
        pattern !~ /^[\w\-\.\+\=\@\%\&\:\,\~\*\?]+$/ # very strict! other special characters can cause shell side-effects!
    end

    CBRAIN::DataProvider_IgnorePatterns.each do |pattern|
      puts "C>\t- DataProvider exclude pattern: '#{pattern}'"
    end
  end
  


  def self.a040_ensure_portal_RemoteResourceId_constant_is_set

    #-----------------------------------------------------------------------------
    puts "C> Ensuring that the CBRAIN::RemoteResourceId constant is set..."
    #-----------------------------------------------------------------------------

    #Assigning this constant here because constant cannot be assigned dynamically inside a method like run_validation 
    dp_cache_md5 = DataProvider.cache_md5
    brainportal  = BrainPortal.find(:first,
                                    :conditions => { :cache_md5 => dp_cache_md5 })
    if brainportal
      CBRAIN.const_set("SelfRemoteResourceId",brainportal.id)
    else
      #----------------------------------------------------------------------------------------
      puts "C> \t- BrainPortal not registered in database, please run this"
      puts "C> \t  command: 'rake db:sanity:check RAILS_ENV=#{ENV['RAILS_ENV']}'."
      #----------------------------------------------------------------------------------------
      puts "C> \t- Note:  You can skip all CBRAIN validations by temporarily setting the\n"
      puts "C> \t         environment variable 'CBRAIN_SKIP_VALIDATIONS' to '1'.\n"
      Kernel.exit(1)
    end
  end



  def self.a050_check_data_provider_cache_wipe

    #-----------------------------------------------------------------------------
    puts "C> Checking to see if Data Provider caches need wiping..."
    #-----------------------------------------------------------------------------

    dp_init_rev    = DataProvider.cache_revision_of_last_init  # will be "0" if unknown
    dp_current_rev = DataProvider.revision_info.svn_id_rev
    raise "Serious Internal Error: I cannot get a numeric SVN revision number for DataProvider?!?" unless
      dp_current_rev && dp_current_rev =~ /^\d+/
    if dp_init_rev.to_i <= CBRAIN::DataProviderCache_RevNeeded # Before Pierre's upgrade
      puts "C> \t- Data Provider Caches are being wiped (Rev: #{dp_init_rev} vs #{dp_current_rev})..."
      puts "C> \t- WARNING: This could take a long time so you should not"
      puts "C> \t  start another instance of this Rails application."
      Dir.chdir(DataProvider.cache_rootdir) do
        Dir.foreach(".") do |entry|
          next unless File.directory?(entry) && entry !~ /^\./ # ignore ., .. and .*_being_deleted.*
          newname = ".#{entry}_being_deleted.#{Process.pid}"
          renamed_ok = File.rename(entry,newname) rescue false
          if renamed_ok
            puts "C> \t\t- Removing old cache subdirectory '#{entry}' in background..."
            system("/bin/rm -rf '#{newname}' </dev/null &")
          end
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



  def self.a070_start_bourreau_ssh_tunnels

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



  def self.a080_ensure_set_starttime_revision

    $CBRAIN_StartTime_Revision = RemoteResource.current_resource.info.revision
    #-----------------------------------------------------------------------------
    puts "C> Current Remote Resource revision number: #{$CBRAIN_StartTime_Revision}"
    #-----------------------------------------------------------------------------

  end

end 
