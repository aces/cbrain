namespace :db do
  namespace :sanity do
   desc "Check the sanity of the BrainPortal model"
   task :check => :environment do
      PortalSanityChecks.check(:all)
   end
  end
end
