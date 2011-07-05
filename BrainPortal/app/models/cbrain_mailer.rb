
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
  
  Revision_info=CbrainFileRevision[__FILE__]
  
  default :from => "no_reply@cbrain.mcgill.ca"

  # Send a registration confirmation to new users.
  def registration_confirmation(user, plain_password, no_password_reset_needed = false)
    @user                     = user
    return unless @user.is_a?(User) && ! @user.email.blank?
    @plain_password           = plain_password
    @no_password_reset_needed = no_password_reset_needed
    mail(
      :to      => user.email,
      :subject => 'Welcome to CBRAIN!'
    )
  end
  
  # Send a password reset e-mail.
  def forgotten_password(user)
    @user = user
    return unless @user.is_a?(User) && ! @user.email.blank?
    mail(
      :to      => user.email,
      :subject => 'Account Reset'
    )
  end
  
  # Send an e-mail notification of a CBRAIN message.
  # Meant to be used by Message.send_message.
  def cbrain_message(users, content = {})
    @users   = users
    return true if @users.blank? || @users.empty?

    @subject = content[:subject] || "No subject"
    @cb_body = content[:body]    || ""  # NOTE: @body is used by Rails!
    @cb_body.gsub!(/\s+\(\[\[.*?\]\]\)/, "")

    mail(
      :to      => users.map(&:email),
      :subject => "CBRAIN Message: #{@subject}"
    )
  end

end
