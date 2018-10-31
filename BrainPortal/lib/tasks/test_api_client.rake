
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

# This task runs a set of API calls to a local server
# running on the test database, to check the CbrainClient Swagger API.
# It should be run on the BrainPortal side with:
#
#    RAILS_ENV=test rake cbrain:api:test:client   # this file
#
# It is necessary to have first prepared the test DB with:
#
#    RAILS_ENV=test rake db:seed:test:api  # (A separate rake task)
#
namespace :cbrain do
  namespace :test do
    namespace :api do
      desc "Test the CBRAIN API client"
      task :client => :environment do
        raise "Error: this task must be run in a TEST environment!" unless
          (ENV["RAILS_ENV"].presence || "Unk") =~ /test/
        CbrainSystemChecks.check([:a002_ensure_Rails_can_find_itself])
        #PortalSystemChecks.check(PortalSystemChecks.all - [:a020_check_database_sanity])
        load "test_api/client_req_tester.rb"
        tester = ClientReqTester.new
        tester.reqfiles_root = Rails.root + "test_api" + "req_files"
        tester.verbose = ENV['CBRAIN_TEST_API_VERBOSE'].presence.try(:to_i) || 1 # TODO make it an arg
        substring      = ENV['CBRAIN_TEST_API_FILTER']  || "" # substring filter, TODO make it an arg
        tester.run_all_tests(substring)
        if tester.failed_tests.present?
          puts "Some tests failed:\n"
          tester.failed_tests.each do |name,errors|
            printf " => %-40s : %s\n",name,errors.join(", ")
          end
        end
        Kernel.exit 1 + tester.failed_tests.size
      end
    end
  end
end

