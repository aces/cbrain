
#
# CBRAIN Project
#
# File manager controller
#
# Original author: Pierre Rioux
#
# $Id$
#

require 'net/http'

class ManagerController < ApplicationController

   Revision_info="$Id$"

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

       userfile         = Userfile.new()
       clean_basename   = ManagerController.clean_base_part_of(upload_stream.original_filename)

       if Userfile.exists?( :base_name => clean_basename, :owner_id => user_id )
           flash[:notice] = "File '" + clean_basename + "' already exists"
           redirect_to :action => :index
           return
       end

       #tmp_type          = upload_stream.content_type.chomp  # not used right now
       userfile.content   = upload_stream.read   # also fills file_size
       userfile.base_name = clean_basename
       userfile.owner_id  = user_id
       userfile.save!

       flash[:notice] = "File '" + clean_basename + "' added"
       redirect_to :action => :index

   end

   def delete
       user_id = session[:user_id]
       userfile = Userfile.find(params[:id])
       if userfile && userfile.owner_id == session[:user_id]
           userfile.destroy
           basename = userfile.base_name
           #vaultfile = userfile.vaultname
           #File.delete(vaultfile) if File.exists?(vaultfile)
           #Userfile.delete(params[:id])
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
       userfiles = Userfile.find_all_by_owner_id(params[:id])
       render :xml => userfiles
     rescue
       render :nothing => true
     end
   end
   
   def minc2jiv

     userfile = Userfile.find(params[:id])
     vaultfile = userfile.vaultname
     content = IO.read(vaultfile)
     directory = Userfile.directory vaultfile
     user_id = session[:user_id]
     
     url = URI.parse('http://localhost:2500/minc2jiv/convert_post')
     resp = Net::HTTP.post_form(url, {:name => File.basename(vaultfile), :content => content, 
                                     :authenticate_token => form_authenticity_token})
    
     name = resp.get_fields('content-disposition')[0].match(/filename="(.+)"/)[1]
     path = File.join(directory, name)
     File.open(path, "wb"){|f| f.write(resp.body)}
     
     base_dir = `pwd`.strip
     
     Dir.chdir(directory)
    `tar xf #{name}`
    #{}`rm #{name}`
     Dir.chdir(base_dir)
     
     subject = File.basename(vaultfile).match(/(.+)\.mnc$/)[1]
     header_file_name = subject + '.header'
     data_file_name = subject + '.raw_byte.gz' 
     
     header_file = Userfile.new()
     
     if !Userfile.exists?( :base_name => header_file_name, :owner_id => user_id )
       header_file.base_name = header_file_name
       header_file.owner_id  = user_id
       header_file.file_size = File.size("#{directory}/#{header_file_name}")
       header_file.save!
     end
     
     data_file = Userfile.new()
     
     if !Userfile.exists?( :base_name => data_file_name, :owner_id => user_id )
        data_file.base_name = data_file_name
        data_file.owner_id  = user_id
        data_file.file_size = File.size("#{directory}/#{data_file_name}")
        data_file.save!
     end
      
      redirect_to :action => :index
   end

   private

   def self.clean_base_part_of(file_name)
     name = File.basename(file_name)
     name.gsub(/[\000-\037\177-\377]/, '')     # sanitize
     name
   end

end
