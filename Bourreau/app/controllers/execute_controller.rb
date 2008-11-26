
#
# CBRAIN Project
#
# Execution controller for the Bourreau service
#
# Original author: Pierre Rioux
#
# $Id$
#

require "pathname"

class ExecuteController < ApplicationController

    Revision_info="$Id$"

    def wordcount
      id = params[:id]
      userfile = Userfile.find(id)
      #tmpfile = userfile.mktemp
      #wcoutio = IO.popen("wc \"#{tmpfile}\"")
      wcoutio = IO.popen("wc \"#{userfile.vaultname}\"")
      wcout = wcoutio.read
      wcoutio.close

      resultfile = Userfile.new(
        :owner_id  => userfile.owner_id,
        :base_name => userfile.base_name + ".wcout",
        :content   => wcout
      )

      ret = resultfile.save()

      answerxml = Hash.new();
      answerxml[:status]     = "Ok I've run \"wc\" on the file"
      answerxml[:wc_out]     = wcout
      answerxml[:retclass]   = ret.class

      respond_to do |format|
        format.html { head :method_not_allowed }
        format.xml { render :xml => answerxml }
      end

    end

    # Takes a minc file, transforms it into a .header and .raw_byte.gz
    def minc2jiv

      # Extract info about request
      mincfile_id        = params[:id]
      mincfile           = Userfile.find(mincfile_id)
      vaultname          = mincfile.vaultname

      # Create work files
      sandbox = SandboxTmp.new()
      sandboxdir = sandbox.tmpfulldirname
      File.symlink(vaultname,(sandbox.tmpfulldirname + "/in.mnc"))
      sandbox.bash("minc2jiv.pl -output_path . in.mnc")

      # Return results
      tmpheader_file  = "#{sandboxdir}/in.header"
      tmprawbyte_file = "#{sandboxdir}/in.raw_byte.gz"
   
      success = 0
      if (File.exists?(tmpheader_file) && File.exists?(tmprawbyte_file))

        owner_id           = mincfile.user.id
        orig_plainbasename = mincfile.name.sub(/\.mnc$/,"")

        headerfile = Userfile.new(
            :user_id  => owner_id,
            :name => orig_plainbasename + ".header",
            :content   => File.read(tmpheader_file)
        )

        success += 1 if headerfile.save
        headerfile.move_to_child_of(mincfile)

        rawbytefile = Userfile.new(
            :user_id  => owner_id,
            :name => orig_plainbasename + ".raw_byte.gz",
            :content   => File.read(tmprawbyte_file)
        )

        success += 1 if rawbytefile.save
        rawbytefile.move_to_child_of(mincfile)
      end

      # Cleanup
      begin
        sandbox.destroy
      rescue
        # Oh well.
      end

      # Return an anwser to our client
      answerxml = Hash.new();
      answerxml[:status]     = "Saved #{success} files."
      #answerxml[:mincfile]   = mincfile.inspect  # much too big!

      respond_to do |format|
        format.html { head   :method_not_allowed }
        format.xml  { render :xml => answerxml }
      end

  end
  
  def run
    render :xml => request.body.read
  end

end
