
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
    @default_data_provider  = current_user.user_preference.data_provider.name rescue "(Unset)"
    @default_bourreau       = current_user.user_preference.bourreau.name rescue "(Unset)"
  end
  
  def credits
  end
  
end
