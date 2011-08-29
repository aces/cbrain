
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

  Revision_info=CbrainFileRevision[__FILE__]
  
  api_available

  def new #:nodoc:
    respond_to do |format|
      format.html
      format.xml
    end
  end

  def create #:nodoc:
    portal = BrainPortal.current_resource

    self.current_user = User.authenticate(params[:login], params[:password])

    # Bad login/password?
    if ! logged_in?
      flash[:error] = 'Invalid user name or password.'
      Kernel.sleep 3 # Annoying, as it blocks the instance for other users too. Sigh.
      
      respond_to do |format|
        format.html { render :action => 'new' }
        format.xml  { render :nothing => true, :status  => 401 }
      end
      return
    end

    # Account locked?
    if self.current_user.account_locked
      self.current_user = nil
      flash.now[:error] = "This account is locked, please write to #{User.admin.email || "the support staff"} to get this account unlocked."
      respond_to do |format|
        format.html { render :action => 'new' }
        format.xml  { render :nothing => true, :status  => 401 }
      end
      return
    end

    # Portal locked?
    if portal.portal_locked? && !current_user.has_role?(:admin)
      self.current_user = nil
      flash.now[:error] = 'The system is currently locked. Please try again later.'
      respond_to do |format|
        format.html { render :action => 'new' }
        format.xml  { render :nothing => true, :status  => 401 }
      end
      return
    end

    # Everything OK
    current_session.activate
    if params[:remember_me] == "1"
      current_user.remember_me unless current_user.remember_token?
      cookies[:auth_token] = { :value => self.current_user.remember_token , :expires => self.current_user.remember_token_expires_at }
    end

    # Record the best guess for browser's remote host name
    reqenv = request.env
    from_ip = reqenv['HTTP_X_FORWARDED_FOR'] || reqenv['HTTP_X_REAL_IP'] || reqenv['REMOTE_ADDR']
    if from_ip
      if from_ip =~ /^[\d\.]+$/
        addrinfo = Socket.gethostbyaddr(from_ip.split(/\./).map(&:to_i).pack("CCCC")) rescue [ from_ip ]
        from_host = addrinfo[0]
      else
        from_host = from_ip # already got name?!?
      end
    else
       from_ip   = '0.0.0.0'
       from_host = 'unknown'
    end
    current_session[:guessed_remote_ip]   = from_ip
    current_session[:guessed_remote_host] = from_host

    # Record the user agent
    raw_agent = reqenv['HTTP_USER_AGENT'] || 'unknown/unknown'
    current_session[:raw_user_agent]     = raw_agent

    # Record that the user logged in
    current_user.addlog("Logged in from #{request.remote_ip}")
    portal.addlog("User #{current_user.login} logged in from #{request.remote_ip}")

    respond_to do |format|
      format.html { redirect_back_or_default('/home') }
      format.xml  { render :nothing => true, :status  => 200 }
    end

  end
  
  def show
    if current_user
      render :nothing  => true, :status  => 200
    else
      render :nothing  => true, :status  => 401
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
