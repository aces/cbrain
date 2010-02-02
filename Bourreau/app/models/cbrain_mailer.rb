#
# CBRAIN Project
#
# CBRAIN mailer
#
# Original author: Tarek Sherif
#
# $Id$
#

#Dummy version of the cbrain mailer for Bourreau.
#Won't send e-mails, but the class is needed for 
#Message.
class CbrainMailer < ActionMailer::Base
  
  Revision_info="$Id$"
  
  #Send an e-mail notification of a CBRAIN message.
  #Meant to be used by Message.send_message.
  def message(users, content = {})
    subject    "Dummy"
    recipients users.map(&:email)
    from       "no_reply@cbrain.mcgill.ca"
    body       ""
  end

end