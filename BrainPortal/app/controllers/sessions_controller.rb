
#
# CBRAIN Project
#
# Sesssions controller for the BrainPortal interface
# This controller handles the login/logout function of the site.  
#
# Original author: restful_authentication plugin
# Modified by: Tarek Sherif
#
# $Id$
#

#Controller for Session creation and destruction.
#Handles logging in and loggin out of the system.
class SessionsController < ApplicationController

  Revision_info="$Id$"

  def create #:nodoc:
    self.current_user = User.authenticate(params[:login], params[:password])
        
    portal = BrainPortal.current_resource
    if logged_in?
      if portal.portal_locked? && !current_user.has_role?(:admin)
        self.current_user = nil
        flash.now[:error] = 'The system is currently locked. Please try again later.'
        render :action  => :new
        return
      end
      
      current_session.activate
      if params[:remember_me] == "1"
        current_user.remember_me unless current_user.remember_token?
        cookies[:auth_token] = { :value => self.current_user.remember_token , :expires => self.current_user.remember_token_expires_at }
      end
      
      respond_to do |format|
        format.html { redirect_back_or_default('/home') }
        format.xml  { render :nothing => true, :status  => 200 }
      end
      current_user.addlog("Logged in from #{request.remote_ip}")
      portal.addlog("User #{current_user.login} logged in from #{request.remote_ip}")
    else
      flash[:error] = 'Invalid user name or password.'
      Kernel.sleep 3 # Annoying, as it blocks the instance for other users too. Sigh.
      
      respond_to do |format|
        format.html { render :action => 'new' }
        format.xml  { render :nothing => true, :status  => 403 }
      end
    end
  end

  def destroy #:nodoc:
    portal = BrainPortal.current_resource
    current_session.deactivate if current_session
    current_user.addlog("Logged out") if current_user
    portal.addlog("User #{current_user.login} logged out") if current_user
    self.current_user.forget_me if logged_in?
    cookies.delete :auth_token
    current_session.clear_data!
    #reset_session
    flash[:notice] = "You have been logged out."
    
    respond_to do |format|
      format.html { redirect_to new_session_path }
      format.xml  { render :nothing => true, :status  => 200 }
    end
  end

end
