class UserfilesController < ApplicationController
  before_filter :login_required
  
  # GET /userfiles
  # GET /userfiles.xml
  def index
    @userfiles = current_user.userfiles.find(:all)

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @userfiles }
    end
  end

  # GET /userfiles/1
  # GET /userfiles/1.xml
  def show
    @userfile = Userfile.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @userfile }
    end
  end

  # GET /userfiles/new
  # GET /userfiles/new.xml
  def new
    @userfile = Userfile.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @userfile }
    end
  end

  # GET /userfiles/1/edit
  def edit
    @userfile = Userfile.find(params[:id])
  end

  # POST /userfiles
  # POST /userfiles.xml
  def create
        upload_stream = params[:upload_file]   # an object encoding the file data stream
        if upload_stream == "" || upload_stream.nil?
          redirect_to :action => :index
          return
        end

        userfile         = Userfile.new()
        clean_basename   = File.basename(upload_stream.original_filename)

        if current_user.userfiles.exists?( :name => clean_basename)
            flash[:notice] = "File '" + clean_basename + "' already exists"
            redirect_to :action => :index
            return
        end

        #tmp_type          = upload_stream.content_type.chomp  # not used right now
        userfile.content   = upload_stream.read   # also fills file_size
        userfile.name = clean_basename
        userfile.user_id  = current_user.id

        if userfile.save
            flash[:notice] = "File '" + clean_basename + "' added"
        else
            flash[:notice] = "File '" + clean_basename + "' could not be added (internal error?)"
        end

        redirect_to :action => :index
  end

  # PUT /userfiles/1
  # PUT /userfiles/1.xml
  def update
    @userfile = Userfile.find(params[:id])

    respond_to do |format|
      if @userfile.update_attributes(params[:userfile])
        flash[:notice] = 'Userfile was successfully updated.'
        format.html { redirect_to(@userfile) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @userfile.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /userfiles/1
  # DELETE /userfiles/1.xml
  def destroy
    @userfile = Userfile.find(params[:id])
    @userfile.destroy

    respond_to do |format|
      format.html { redirect_to(userfiles_url) }
      format.xml  { head :ok }
    end
  end
  
  def operation
     operation   = params[:operation]
     filelist    = params[:filelist] || []

     flash[:error]  ||= ""
     flash[:notice] ||= ""

     #flash[:error] += "Operation #{operation} filelist '#{filelist.join(",")}'\n"

     if operation.nil? || operation.empty?
       flash[:error] += "No operation selected? Selection cleared.\n"
       redirect_to :action => :index
       return
     end

     if filelist.empty?
       flash[:error] += "No file selected? Selection cleared.\n"
       redirect_to :action => :index
       return
     end

     # TODO: filter out right away from the filelist IDs that do not belong to the user

     # TODO: replace "case" and make each operation a private method ?
     case operation

       when "Delete"

         filelist.each do |id|
           userfile = current_user.userfiles.find(id)
           if userfile.nil?
             flash[:error] += "File #{id} doesn't exist or is not yours.\n"
             next
           end
           basename = userfile.name
           userfile.destroy
           flash[:notice] += "File #{basename} deleted.\n"
         end

       when "Convert MINC to JIV"

         #flash[:error] = "Minc2JIV not yet implemented"
         filelist.each do |id|
           userfile = current_user.userfiles.find(id)
           if userfile.nil?
             flash[:error] += "File #{id} doesn't exist or is not yours.\n"
             next
           end
           basename = userfile.name

           if basename !~ /\.mnc$/
             flash[:error] += "File #{basename} doesn't seem to be a MINC file (no .mnc extension)\n"
             next
           end

           # Temporary; should use new general exec mechanism
           # with CBRAIN::Bourreau_execution_URL

           url  = URI.parse("http://localhost:2500/execute/minc2jiv/#{id}.xml")
puts("Calling #{url.to_s}\n")
           resp = Net::HTTP.get_response(url)
           xml  = resp.body.to_s # xml text
puts("GOT XML: #{xml}---\n");
           if xml =~ /Saved 2 files/i       # temporary; this DEPENDS on XML created by minc2jiv()
               flash[:notice] += "Properly converted '#{basename}'\n"
           else
               flash[:error]  += "- Problem converting '#{basename}':<PRE>#{xml}</PRE>\n"
           end


         end

       when "wait"

         sleep 20
         flash[:error] = "Slept for some time\n"

       else

         flash[:error] = "Unknown operation #{operation}"

     end

     redirect_to :action => :index
   end
  
end
