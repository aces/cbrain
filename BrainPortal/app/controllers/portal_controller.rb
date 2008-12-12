
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
    @local_request = local_request?
  end
  
  if RAILS_ENV == 'development'
    def toggle_local_status
      if local_request?
        CBRAIN.const_set(:LOCAL_STATUS, false)
      else
        CBRAIN.const_set(:LOCAL_STATUS, true)
      end
      redirect_to :action => "welcome"    
    end
  end
end
