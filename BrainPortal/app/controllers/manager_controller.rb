class ManagerController < ApplicationController

   before_filter :authorize, :except => [:content, :list]    # in application.rb

   def index
       user_id = session[:user_id]
       @userfiles = Userfile.find(:all, :conditions => { :owner_id => user_id } )
   end

   def upload
       upload_stream = params[:upload_file]   # an object encoding the file data stream
       if upload_stream == "" || upload_stream.nil?
         redirect_to :action => :index
         return
       end

       user_id = session[:user_id]
       userfile = Userfile.new()
       userfile.upload_file(upload_stream) # this init tmp_basename, tmp_type and content

       basename = userfile.tmp_basename
       if Userfile.exists?( :base_name => basename, :owner_id => user_id )
           flash[:notice] = "File '" + basename + "' already exists"
           redirect_to :action => :index
           return
       end

       userfile.base_name = basename
       userfile.owner_id  = user_id
       userfile.file_size = userfile.content.size
       userfile.save!

       out = File.new(userfile.vaultname, "w")
       out.write(userfile.content)
       out.close()

       flash[:notice] = "File '" + basename + "' added"
       redirect_to :action => :index
   end

   def delete
       user_id = session[:user_id]
       userfile = Userfile.find(params[:id])
       if userfile && userfile.owner_id == session[:user_id]
           basename = userfile.base_name
           vaultfile = userfile.vaultname
           File.delete(vaultfile) if File.exists?(vaultfile)
           Userfile.delete(params[:id])
           flash[:notice] = "File '" + basename + "' deleted"
       end
       redirect_to :action => "index"
   end

   def content
     begin
       userfile = Userfile.find(params[:id])
       #vaultfile = userfile.vaultname
       #content = IO.read(vaultfile)
       # userfile.content = content
       #result = Hash.new()
       #result[:userfile] = userfile
       #result[:content]  = content
       #render :xml => result 
       
       #render :text => content
       send_file userfile.vaultname
       return
     rescue
       render :nothing => true
     end
   end
   
   def list
     begin
       userfiles = Userfile.find(:all)
       render :xml => userfiles
     rescue
       render :nothing => true
     end
   end

end
