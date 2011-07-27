
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
  
  Revision_info=CbrainFileRevision[__FILE__]

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
        puts "C> \t- Please run \"rake db:migrate RAILS_ENV=#{Rails.env}\" to update"
        puts "C> \t  your database then try again."
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
      puts "C> \t         command: 'rake db:sanity:check RAILS_ENV=#{Rails.env}'." 
      Kernel.exit(1)
    end
  end



  def self.a022_ensure_more_configuration_variables_are_unset
    
    old_Constants = {
                       'DataProviderCache_dir'           => :dp_cache_dir,
                       'DataProviderCache_RevNeeded'     => nil,
                       'DataProvider_IgnorePatterns'     => :dp_ignore_patterns,
                       'Site_URL'                        => :site_url_prefix
                     }

    CbrainSystemChecks.move_old_config_vars("portal", old_Constants)

  end

end 
