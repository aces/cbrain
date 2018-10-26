
#
# CBRAIN Project
#
# Copyright (C) 2008-2012
# The Royal Institution for the Advancement of Learning
# McGill University
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# Seeds the database for use in Bourreau rspec tests
# Should run on the BrainPortal side with: RAILS_ENV=test rake db:seed:test:bourreau
namespace :db do
  namespace :seed do
    namespace :test do
      desc "Seed CBRAIN test DB for API testing"
      task :api => :environment do
        raise "Error: this task must be run in a TEST environment!" unless
          (ENV["RAILS_ENV"].presence || "Unk") =~ /test/
        CbrainSystemChecks.check([:a002_ensure_Rails_can_find_itself])
        #PortalSystemChecks.check(PortalSystemChecks.all - [:a020_check_database_sanity])
        load "db/seeds_test_api.rb"
      end
    end
  end
end

