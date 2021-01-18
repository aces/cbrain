#!/bin/bash

# This scripts outputs in STDOUT the Rails
# initializer for the CBRAIN config file,
# which only contains a name.

cat <<RAILS_CONFIG_INITIALIZER_CBRAIN

#
# File created automatically by $0
#
class CBRAIN
  CBRAIN_RAILS_APP_NAME = "TestPortal"
end

RAILS_CONFIG_INITIALIZER_CBRAIN

