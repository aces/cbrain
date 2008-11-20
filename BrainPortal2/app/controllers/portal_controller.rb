class PortalController < ApplicationController
  before_filter :login_required
  
  def welcome
  end

end
