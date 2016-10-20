
#
# CBRAIN Project
#
# Copyright (C) 2008-2012
# The Royal Institution for the Advancement of Learning
# McGill University
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

#ActionMailer subclass for sending system e-mails.
class CbrainMailer < ActionMailer::Base

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Patch for Rails 3.1 charset warning. Should be fixed in
  # Rails 3.2
  def charset #:nodoc:
    @charset
  end

  # Send a registration confirmation to new users.
  def registration_confirmation(user, plain_password, no_password_reset_needed = false)
    @user                     = user
    @plain_password           = plain_password
    @no_password_reset_needed = no_password_reset_needed
    return unless @user.is_a?(User) && ! @user.email.blank?
    mail(
      :from    => build_from,
      :to      => user.email,
      :subject => 'Welcome to CBRAIN!'
    )
  end

  # Send a password reset email.
  def forgotten_password(user)
    @user = user
    return unless @user.is_a?(User) && ! @user.email.blank?
    mail(
      :from    => build_from,
      :to      => user.email,
      :subject => 'Account Reset'
    )
  end

  # Send an e-mail notification of a CBRAIN message.
  # Meant to be used by Message.send_message.
  def cbrain_message(users, content = {})
    @users   = users

    @subject = content[:subject] || "No subject"
    @cb_body = content[:body]    || ""  # NOTE: @body is used by Rails!
    @cb_body.gsub!(/\s+\(?\[\[.*?\]\]\)?/, "")

    return true if @users.blank? || @users.empty?

    emails = users.map(&:email).compact.uniq.reject { |email| email.blank? || email =~ /\A(nobody|no-?reply|sink)@/i }
    return false if emails.empty?

    mail(
      :from    => build_from,
      :to      => emails.size == 1 ? emails : [],
      :bcc     => emails.size  > 1 ? emails : [],
      :subject => "CBRAIN Message: #{@subject}"
    )
  end

  # Sends an email asking to verify a user's email address by clicking a link
  def signup_request_confirmation(signup, confirm_url)
    @signup      = signup
    @confirm_url = confirm_url
    return if signup.confirm_token.blank? || signup.email.blank? || confirm_url.blank?
    mail(
      :from    => RemoteResource.current_resource.system_from_email,
      :to      => @signup.email,
      :subject => "Confirmation of CBRAIN Account Request"
    )
  end

  # Sends an email to the administrator
  def signup_notify_admin(signup, show_url)
    @signup     = signup
    @show_url   = show_url
    admin_email = RemoteResource.current_resource.support_email
    return if admin_email.blank?
    subject  = "CBRAIN Account Request from '#{@signup.full}'"
    subject += " at '#{@signup.institution}'" if @signup.institution.present?
    mail(
      :from    => RemoteResource.current_resource.system_from_email,
      :to      => admin_email,
      :subject => subject
    )
  end

  private

  def build_from #:nodoc:
    RemoteResource.current_resource.system_from_email.presence ||
    "#{CBRAIN::Rails_UserName}@#{Socket.gethostname}"
  end

end
