class LoginController < ApplicationController

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
        users = User.find(:all, :conditions => { :user_name => username } )
        raise "No such user" if users.size != 1
        user = users[0]
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

    def logout
      session[:user_id] = nil
      flash[:notice] = "Goodbye. You are no longer logged in."
      redirect_to :action => :index
    end

end
