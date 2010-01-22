class CbrainMailer < ActionMailer::Base
  def registration_confirmation(user)
    subject     'Welcome to CBRAIN!'
    recipients  user.email
    from        "no_reply@cbrain.mcgill.ca"
    body        :user  => user
  end
  
  def forgotten_password(user)
    subject     'Account Reset'
    recipients  user.email
    from        "no_reply@cbrain.mcgill.ca"
    body        :user  => user
  end

end
