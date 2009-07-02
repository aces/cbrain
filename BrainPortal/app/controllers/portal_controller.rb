
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
    unless current_user
      redirect_to login_path 
      return
    end
    
    @num_files              = current_user.userfiles.size
    @groups                 = current_user.groups.collect{|g| g.name}.join(', ')
    @default_data_provider  = current_user.user_preference.data_provider.name if current_user.user_preference.data_provider
    @default_bourreau       = current_user.user_preference.bourreau_id
  end
  
  def credits
  end
  
end
