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

class Checker 
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
    
    if checks_to_run == :all
      checks=self.all
      checks.each do |check|

        self.send(check) #This line is a metaprogramming technique. 
                         #it asks the class to run the methods named after the symbol 
                         #stored in check   
      end
    
    else
    checks_to_run.each do |check| #run each test requested
        self.send(check)
      end
    end
    
  end
end




















