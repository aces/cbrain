
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
      userfile.after_find
      tmpfile = userfile.mktemp
      wcoutio = IO.popen("wc \"#{tmpfile}\"")
      wcout = wcoutio.read
      wcoutio.close

      resultfile = Userfile.new(
        :owner_id  => userfile.owner_id,
        :base_name => userfile.base_name + ".wcout",
        :content   => wcout
      )

      ret = resultfile.save()

      answerxml = Hash.new();
      answerxml[:status]     = "Ok I've done it"
      answerxml[:wc_out]     = wcout
      #answerxml[:ret]        = ret
      answerxml[:retclass]   = ret.class
      #answerxml[:resultfile] = Userfile.headers

      respond_to do |format|
        format.html { head :method_not_allowed }
        format.xml { render :xml => answerxml }
      end

    end

    # Takes a minc file, transforms it into a .header and .raw_byte.gz
    # TODO: run convertion is a properly controlled sandbox
    def minc2jiv

      # Extract info about request
      mincfile_id        = params[:id]
      mincfile           = Userfile.find(mincfile_id)
      mincfile.after_find  # PATCH. Once active resource implements callbacks, remove this

      # Create work files
      tmpmincfile = mincfile.mktemp(:ext => ".mnc")  # path to a copy of the content

      # This is all clumsy, we need a simpler /tmp execution sandbox
      pathtmpfile       = Pathname.new(tmpmincfile)
      pathdir, pathbase = pathtmpfile.split
      tmpdir    = pathdir.to_s
      plainbase = pathbase.to_s.sub(/\.mnc$/,"")    # needed to find the outputs
      
      # Convert
      system("minc2jiv.pl -output_path \"#{tmpdir}\" \"#{tmpmincfile}\"")
      #system("echo 'minc2jiv.pl -output_path \"#{tmpdir}\" \"#{tmpmincfile}\"'")

      # Return results
      tmpheader_file  = "#{tmpdir}/#{plainbase}.header"
      tmprawbyte_file = "#{tmpdir}/#{plainbase}.raw_byte.gz"
   
      success = 0
      if (File.exists?(tmpheader_file) && File.exists?(tmprawbyte_file))

        owner_id           = mincfile.owner_id
        orig_plainbasename = mincfile.base_name.sub(/\.mnc$/,"")

        headerfile = Userfile.new(
            :owner_id  => owner_id,
            :base_name => orig_plainbasename + ".header",
            :content   => File.read(tmpheader_file)
        )

        success += 1 if headerfile.save

        rawbytefile = Userfile.new(
            :owner_id  => owner_id,
            :base_name => orig_plainbasename + ".raw_byte.gz",
            :content   => File.read(tmprawbyte_file)
        )

        success += 1 if rawbytefile.save
      end

      # Cleanup
      begin
        #File.unlink(tmpmincfile)
        #File.unlink(tmpheader_file)
        #File.unlink(tmprawbyte_file)
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

end
