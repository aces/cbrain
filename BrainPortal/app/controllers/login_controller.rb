
#
# CBRAIN Project
#
# Login controller
#
# Original author: Pierre Rioux
#
# $Id$
#

class LoginController < ApplicationController

    Revision_info="$Id$"

    def index
      if session[:user_id]
        redirect_to :action => :welcome
      end
    end

    def authenticate
      if session[:user_id]
        redirect_to :action => :welcome
      end
      username = params[:username] || "Nothing"
      password = params[:password] || "Nothing"
      begin
        user = User.find_by_user_name(username)
        raise "No such user" if user.nil?
        dbpasswd = user.crypt_password
        salt     = dbpasswd[0,2]
        upassword = password.crypt(salt)
        if upassword != dbpasswd
          raise "Password mismatch"
        end
        session[:user_id] = user.id
        redirect_to :action => :welcome
      rescue Exception => whatisit
        # logger.error("Invalid username/password: #{username} : #{password}" + whatisit)
        flash[:notice] = "Invalid username or password: " + whatisit
        redirect_to :action => :index
      end
    end

    def welcome
      if !session[:user_id]
          redirect_to :action => :index
      end
    end
    
    def check_auth
      if params[:id] && params[:id].to_i == session[:user_id].to_i
        render :xml => {:answer => 'yes'}
      else
        render :xml => {:answer => 'no'}
      end
    end

    def logout
      session[:user_id] = nil
      flash[:notice] = "Goodbye. You are no longer logged in."
      redirect_to :action => :index
    end

end
