#
# CBRAIN Project
#
# Set up initialization environment for BrainPortal and Bourreau
#
# Original author: Tarek Sherif
#
# $Id$
#

if File.exists? File.join(RAILS_ROOT, "config", "conditional_initializers", "configuration.rb")
  require File.join(RAILS_ROOT, "config", "conditional_initializers", "configuration.rb")
else
  module Initialization_Configuration
    Configuration = 'full'
  end 
end

class HostConfigInfo
  include Initialization_Configuration
end