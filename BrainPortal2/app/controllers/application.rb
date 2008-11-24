# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  include AuthenticatedSystem
  helper_method :check_role, :not_admin_user
  helper :all # include all helpers, all the time

  # See ActionController::RequestForgeryProtection for details
  # Uncomment the :secret if you're not using the cookie session store
  protect_from_forgery # :secret => 'b5e7873bd1bd67826a2661e01621334b'
  
  # See ActionController::Base for details 
  # Uncomment this to filter the contents of submitted sensitive data parameters
  # from your application log (in this case, all fields with names like "password"). 
  # filter_parameter_logging :password
  
  protected
    
  def check_role(role)
    current_user && current_user.role.to_sym == role
  end
  
  def not_admin_user(user)
    user && user.login != 'admin'
  end
  
  def edit_permission?(user)
    current_user && user && (current_user == user || current_user.role == 'admin')
  end
end
