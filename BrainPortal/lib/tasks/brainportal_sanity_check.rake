require 'lib/portal_sanity_checks'

namespace :db do
  namespace :sanity do
   desc "Check the sanity of the BrainPortal model"
   task :check => :environment do
      PortalSanityCheck.check(:all)
   end
  end
end