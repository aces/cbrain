puts "C> Checking for pending migrations"

unless ARGV[0] == "db:migrate"
  if defined? ActiveRecord
    pending_migrations = ActiveRecord::Migrator.new(:up, 'db/migrate').pending_migrations
    if pending_migrations.any?
      puts "You have #{pending_migrations.size} pending migrations:"
      pending_migrations.each do |pending_migration|
        puts '  %4d %s' % [pending_migration.version, pending_migration.name]
      end
      raise %{Run "rake db:migrate" to update your database then try again.}
    end
    
  end
end
