
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

# Checker class implementing the runtime and sanity check framework.
#
# This class implements 2 core methods to the runtime and database check system
# The check command is used to run all methods of a class (defined in subclasses)
# which start with ensure_, check_ or start_. In addion, these methods can be
# prioritized by adding a number after the ensure_/check_/start_ in the method name
# Example method defined in subclass
#
#  def self.ensure_the_truth_is_true
#    if true
#      #-------------------------------------------
#      puts "C> Truth has been confirmed to be true
#      #-------------------------------------------
#    end
#  end
#
# There is also a self.all method which returns a sorted list of all the tests as an array.
class CbrainChecker

  include Singleton

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Collects all the checks and start methods defined in the class
  # Puts them in an array to be used by the run_checks command.
  def self.all
    checks = []
    self.methods.sort.each do |method|
      if method.to_s.include?('check_') or method.to_s.include?('start_') or method.to_s.include?('ensure_')
        checks << method.to_sym
      end
    end
    checks
  end


  # Runs the checks that are in the check_to_run array
  def self.check(checks_to_run, options={})

    checks  = checks_to_run == :all ? self.all : checks_to_run
    checks -= options[:except] if options[:except].present?

    checks.each do |check|
      begin
        self.send(check)
      rescue => failed_check
        puts "\n"
        puts "CBRAIN initial check failed: #{check}"
        puts failed_check.message
        puts failed_check.backtrace.select { |m| m.to_s.include?(Rails.root.to_s) }.join("\n")
        raise SystemExit.new("CBRAIN process failed initial checks.")
      end
    end

  end

end

