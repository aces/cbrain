
#
# CBRAIN Project
#
# Execution controller for the Bourreau service
#
# Original author: Pierre Rioux
#
# $Id$
#

class ExecuteController < ApplicationController

    Revision_info="$Id$"

    def wordcount
        id = params[:id]
        userfile = Userfile.find(id)
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
        #answerxml[:ret]        = ret
        answerxml[:retclass]   = ret.class
        #answerxml[:resultfile] = Userfile.headers

        respond_to do |format|
          format.html { head :method_not_allowed }

          format.xml { render :xml => answerxml }
        end

    end

end
