
#
# CBRAIN Project
#
# Contoller for the entrypoint to cbrain
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
