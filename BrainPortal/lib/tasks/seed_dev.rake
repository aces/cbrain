
namespace :db do
  namespace :seeds do
    desc "Seed CBRAIN with developer records"
    task :dev => :environment do
      CbrainSystemChecks.check(:all)
      PortalSystemChecks.check(PortalSystemChecks.all - [:a020_check_database_sanity])
      load "db/seeds_dev.rb"
    end
  end
end

