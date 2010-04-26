
#
# CBRAIN Project
#
# CBRAIN mailer
#
# Original author: Tarek Sherif
#
# $Id$
#

#ActionMailer subclass for sending system e-mails.
class CbrainMailer < ActionMailer::Base
  
  Revision_info="$Id$"
  
  #Send a registration confirmation to new users.
  def registration_confirmation(user)
    subject     'Welcome to CBRAIN!'
    recipients  user.email
    from        "no_reply@cbrain.mcgill.ca"
    body        :user  => user
  end
  
  #Send a password reset e-mail.
  def forgotten_password(user)
    subject     'Account Reset'
    recipients  user.email
    from        "no_reply@cbrain.mcgill.ca"
    body        :user  => user
  end
  
  #Send an e-mail notification of a CBRAIN message.
  #Meant to be used by Message.send_message.
  def message(users, content = {})
    subject    "CBRAIN Message: #{content[:subject]}"
    recipients users.map(&:email)
    from       "no_reply@cbrain.mcgill.ca"
    body       :content  => content
  end

end
