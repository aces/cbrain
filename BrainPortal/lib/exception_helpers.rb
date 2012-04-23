
#
# CBRAIN Project
#
# Copyright (C) 2008-2012
# The Royal Institution for the Advancement of Learning
# McGill University
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.  
#

module ExceptionHelpers

  Revision_info=CbrainFileRevision[__FILE__]

  def self.included(includer)
    includer.class_eval do 
      rescue_from Exception,                       :with => :generic_exception
      rescue_from ActiveRecord::RecordNotFound,    :with => :record_not_found
      rescue_from ActionController::UnknownAction, :with => :unknown_action
      rescue_from CbrainException,                 :with => :cb_exception
    end 
  end

  protected
  # Record not accessible
  def record_not_found(exception)
    raise unless Rails.env == 'production' #Want to see stack trace in dev.
    flash[:error] = "The object you requested does not exist or is not accessible to you."
    respond_to do |format|
      format.html { redirect_to default_redirect }
      format.js   { render :partial  => "shared/flash_update",     :status => 404 } 
      format.xml  { render :xml => {:error  => exception.message}, :status => 404 }
    end
  end

  # Action not accessible
  def unknown_action(exception)
    raise unless Rails.env == 'production' #Want to see stack trace in dev.
    flash[:error] = "The page you requested does not exist."
    respond_to do |format|
      format.html { redirect_to default_redirect }
      format.js   { render :partial  => "shared/flash_update",     :status => 400 } 
      format.xml  { render :xml => {:error  => exception.message}, :status => 400 }
    end
  end
  
  # Internal CBRAIN errors
  def cb_exception(exception)
    if exception.is_a? CbrainNotice
      flash[:notice] = exception.message    # + "\n" + cbm.backtrace[0..5].join("\n")
    else
     flash[:error]   = exception.message    # + "\n" + cbm.backtrace[0..5].join("\n")
    end
    logger.error "CbrainException for controller #{params[:controller]}, action #{params[:action]}: #{exception.class} #{exception.message}"
    respond_to do |format|
      format.html { redirect_to exception.redirect || default_redirect }
      format.js   { render :partial  => "shared/flash_update",     :status => exception.status } 
      format.xml  { render :xml => {:error  => exception.message}, :status => exception.status }
    end
  end

  # Anything else is serious
  def generic_exception(exception)
    raise unless Rails.env == 'production' #Want to see stack trace in dev. Also will log it in exception logger

    # Note that send_internal_error_message will also censure :password from the params hash
    Message.send_internal_error_message(current_user, "Exception Caught", exception, params) rescue true
    log_exception(exception) # explicit logging in exception logger, since we won't re-raise it now.
    flash[:error] = "An error occurred. A message has been sent to the admins. Please try again later."
    logger.error "Exception for controller #{params[:controller]}, action #{params[:action]}: #{exception.class} #{exception.message}"
    respond_to do |format|
      format.html { redirect_to default_redirect }
      format.js   { render :partial  => "shared/flash_update",     :status => 500 } 
      format.xml  { render :xml => {:error  => exception.message}, :status => 500 }
    end
  end
  
  # Redirect to the index page if available and wasn't the source of
  # the exception, otherwise to welcome page.
  def default_redirect
    final_resting_place = { :controller => "portal", :action => "welcome" }
    if self.respond_to?(:index) && params[:action] != "index"
      { :action => :index }
    elsif final_resting_place.keys.all? { |k| params[k] == final_resting_place[k] }
      "/500.html" # in case there's an error in the welcome page itself
    else
      url_for(final_resting_place)
    end
  end

end
