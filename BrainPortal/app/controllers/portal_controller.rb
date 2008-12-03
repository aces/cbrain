
#
# CBRAIN Project
#
# Portals controller for the BrainPortal interface
#
# Original author: Tarek Sherif
#
# $Id$
#

class PortalController < ApplicationController

  Revision_info="$Id$"
  
  def welcome
    redirect_to '/login/' unless current_user      
  end

end
