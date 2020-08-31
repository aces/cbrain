
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

# This task runs some property checkers with results compatible
# with NAGIOS.
namespace :cbrain do
  namespace :nagios do
    namespace :checkers do
      desc "Invokes CBRAIN DataProviders 'is_alive?'"

      # Silence STDOUT and STDERR while the environment loads.
      # We do this if we guess that the rake task being
      # invoked in a nagios checker.
      if ARGV.any? { |x| x =~ /cbrain:nagios:checkers/ }
        nagios_out = STDOUT.dup
        nagios_err = STDERR.dup
        STDOUT.reopen "/dev/null", "w"
        STDERR.reopen "/dev/null", "w"
      end

      #####################################################
      # NAGIOS CHECKER: DATA PROVIDERS
      #####################################################
      task :dps => :environment do

        # Restores STDOUT and STDERR so that nagios
        # can capture our pretty message at the end.
        STDOUT.reopen(nagios_out) if nagios_out
        STDERR.reopen(nagios_err) if nagios_err

        retcode  = 0
        messages = []

        # There is no good way to provide standard command line
        # args to a rake task, so I have to butcher ARGV myself.
        args = ARGV.size > 1 ? ARGV[1..ARGV.size-1] : [] # remove 'rake'
        while args.size > 0 && args[0] =~ /^cbrain:nagios:checkers|^-/ # remove options and task name
          args.shift
        end

        # Loop through the DPs, which can be specified by name or ID
        args.each do |dpid| # can be name too
          dp = DataProvider.where_id_or_name(dpid).first

          if !dp
            messages << "UNKNOWN: DataProvider #{dpid} not found"
            retcode = 3 if retcode < 2
            next
          end

          dpid=dp.name # for pretty

          if ! dp.online?
            messages << "WARNING: DataProvider #{dpid} is offline"
            retcode = 1 if retcode == 0
            next
          end

          alive = dp.is_alive? rescue nil

          if alive.nil?
            messages << "UNKNOWN: DataProvider #{dpid} cannot be checked"
            retcode = 3 if retcode == 0
            next
          end

          if ! alive
            messages << "ERROR: DataProvider #{dpid} is not alive"
            retcode = 2
            next
          end

          if alive
            messages << "OK: #{dpid}"
            next
          end
        end

        er_msgs = messages.grep /^ERROR/i
        ok_msgs = messages.grep /^OK/i
        wa_msgs = messages.grep /^WARN/i
        uk_msgs = messages.grep /^UNK/i

        # Print messages in order of criticality
        joined = (er_msgs + wa_msgs + uk_msgs + ok_msgs).join(', ')
        puts joined

        Kernel.exit retcode
      end # task dps

      #####################################################
      # OTHER NAGIOS CHECKERS: ADD HERE
      #####################################################

    end
  end
end

