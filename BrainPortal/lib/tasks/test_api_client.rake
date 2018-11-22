
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
#    RAILS_ENV=test rake cbrain:test:api:client
# or
#    RAILS_ENV=test rake cbrain:test:api:client -- -v5 myfilter
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

        # There is no good way to provide standard command line
        # args to a rake task, so I have to butcher ARGV myself.
        verbose = ENV['CBRAIN_TEST_API_VERBOSE'].presence.try(:to_i) || 1
        filter  = ENV['CBRAIN_TEST_API_FILTER']                      || ""
        args    = ARGV.size > 1 ? ARGV[1..ARGV.size-1] : []
        args.shift if args[0] == '--'
        while args.present?
          break unless args[0] =~ /^-v/
          if args[0] =~ /^-v=?(\d+)/            # -v3
            verbose = Regexp.last_match[1].to_i
            args.shift
          elsif args[0] == "-v" && args.size > 1 && args[1] =~ /^\d+$/  # -v 3
            verbose = args[1].to_i
            args.shift;args.shift
          elsif args[0] == "-v"    # -v
            verbose += 1
            args.shift
          else
            raise "Invalid argument: #{args[0]}"
          end
        end
        if args.size == 1
          filter = args[0]
        elsif args.size > 1
          raise "Only one filter argument supported."
        end

        # Minimum boot tests
        CbrainSystemChecks.check([:a002_ensure_Rails_can_find_itself])

        # We load the tester class explicitely, it's not in the load path.
        load "test_api/ruby_req_tester.rb"

        # Run the tests and report
        tester = ClientReqTester.new
        tester.reqfiles_root = Rails.root + "test_api" + "req_files"
        tester.verbose = verbose
        tester.run_all_tests(filter)
        if tester.failed_tests.present?
          puts "Some tests failed:\n"
          tester.failed_tests.each do |name,errors|
            printf " => %-40s : %s\n",name,errors.join(", ")
          end
        end

        # If we don't exit explicitely, rake will complain
        # about anything left on ARGV...
        Kernel.exit tester.failed_tests.size
      end
    end
  end
end

