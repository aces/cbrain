class PortalController < ApplicationController
  
  def welcome
    redirect_to '/login/' unless current_user      
  end

end
