# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
#
# CBRAIN project
#
# $Id$

class ApplicationController < ActionController::Base

  Revision_info="$Id$"

  include AuthenticatedSystem
  include ExceptionLoggable

  helper_method :check_role, :not_admin_user, :current_session
  helper_method :available_data_providers, :available_bourreaux
  helper :all # include all helpers, all the time
  filter_parameter_logging :password, :login, :email, :full_name, :role

  # See ActionController::RequestForgeryProtection for details
  # Uncomment the :secret if you're not using the cookie session store
  protect_from_forgery :secret => 'b5e7873bd1bd67826a2661e01621334b'  
  
  # See ActionController::Base for details 
  # Uncomment this to filter the contents of submitted sensitive data parameters
  # from your application log (in this case, all fields with names like "password"). 
  # filter_parameter_logging :password
  
  private
    
  def check_role(role)
    current_user && current_user.role.to_sym == role
  end
  
  def not_admin_user(user)
    user && user.login != 'admin'
  end
  
  def edit_permission?(user)
    current_user && user && (current_user == user || current_user.role == 'admin')
  end
  
  def current_session
    @session ||= Session.new(session)
  end

  def available_data_providers(user)
    DataProvider.find(:all, :conditions => { :online => true, :read_only => false }).select { |p| p.can_be_accessed_by(user) }
  end

  def available_bourreaux(user)
    Bourreau.find(:all, :conditions => { :online => true  }).select { |p| p.can_be_accessed_by(user) }
  end

end

LoggedExceptionsController.class_eval do
  # set the same session key as the app
  session :session_key => '_BrainPortal2_session'
  
  include AuthenticatedSystem
  protect_from_forgery :secret => 'b5e7873bd1bd67826a2661e01621334b'

  before_filter :login_required, :admin_role_required

  # optional, sets the application name for the rss feeds
  self.application_name = "BrainPortal"
end
