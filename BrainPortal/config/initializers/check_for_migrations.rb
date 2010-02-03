
#
# CBRAIN Project
#
# Migration Checking Initializer
#
# Original author: Nicolas Kassis
#
# $Id$
#

#-----------------------------------------------------------------------------
puts "C> Checking for pending migrations..."
#-----------------------------------------------------------------------------

unless ARGV[0] == "db:migrate" or ARGV[0] == "migration" 
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

