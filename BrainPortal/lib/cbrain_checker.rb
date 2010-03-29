#
# CBRAIN Project
#
# Checker class implementing the runtime and sanity check framework.
#
# Original author: Nicolas Kassis
#
# $Id$
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
# There is also a self.all method which returns a sorted list of all the tests as an array.\
# One can except a test 
# 

class CbrainChecker 
  include Singleton
  RevisionInfo="$Id$"

  #Collects all the checks and start methods defined in the class 
  #Puts them in an array to be used by the run_checks command. 
  def self.all
    checks = []
    self.methods.sort.each do |method|
      if method.to_s.include?('check_') or method.to_s.include?('start_') or method.to_s.include?('ensure_')
        checks << method.to_sym
      end
    end
    checks
  end
  
  
  #Runs the checks that are in the check_to_run array
  def self.check(checks_to_run)
    
    checks = checks_to_run == :all ? self.all : checks_to_run

    checks.each do |check|
      begin
        self.send(check)
      rescue => failed_check
        puts "\n"
        puts "CBRAIN initial check failed: #{check}"
        puts failed_check.message
        raise SystemExit.new("CBRAIN process failed initial checks.")
      end
    end

  end

end




















