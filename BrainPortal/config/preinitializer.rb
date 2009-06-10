#
# CBRAIN Project
#
# Set up initialization environment for BrainPortal and Bourreau
#
# Original author: Tarek Sherif
#
# $Id$
#

require File.join(RAILS_ROOT, "config", "conditional_initializers", "configuration.rb")

class HostConfigInfo
  include Initialization_Configuration
end
