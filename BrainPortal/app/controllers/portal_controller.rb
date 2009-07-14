
#
# CBRAIN Project
#
# Contoller for the entrypoint to cbrain
#
# Original author: Tarek Sherif
#
# $Id$
#

#Controller for the entry point into the system.
class PortalController < ApplicationController

  Revision_info="$Id$"
  
  #Display a user's home page with information about their account.
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
  
  #Display general information about the CBrain project.
  def credits

    @revinfo = { 'Revision'            => 'unknown',
                 'Last Changed Author' => 'unknown',
                 'Last Changed Rev'    => 'unknown',
                 'Last Changed Date'   => 'unknown'
               }

    IO.popen("svn info #{RAILS_ROOT}","r") do |fh|
      fh.each do |line|
        if line.match(/^Revision|Last Changed/i)
          comps = line.split(/:\s*/,2)
          field = comps[0]
          value = comps[1]
          @revinfo[field]=value
        end
      end
    end

  end
  
end
