
class ConfirmMailer < ActionMailer::Base

  helper  :demands

  default :from => NewAccountOfferings::EmailFrom

  def request_confirmation(demand, confirm_url)
    @demand      = demand
    @confirm_url = confirm_url
    return if demand.confirm_token.blank? || demand.email.blank? || confirm_url.blank?
    mail(
      :to      => @demand.email,
      :subject => "Confirmation of New Account Request: #{@demand.service}"
    )
  end

  def notify_admin(demand, login_url, show_url)
    @demand     = demand
    @login_url  = login_url
    @show_url   = show_url
    admin_email = NewAccountOfferings::AdminNotificationEmail
    return if admin_email.blank?
    subject  = "[NewAccount] Request '#{@demand.service}' from '#{@demand.full}'"
    subject += " at '#{@demand.institution}'" if @demand.institution.present?
    mail(
      :to      => admin_email,
      :subject => subject
    )
  end

  def account_created(demand, plain_password = nil)
    @demand         = demand
    @url            = NewAccountOfferings::ServiceList[@demand.service][1] rescue ""
    @plain_password = plain_password
    mail(
      :to      => @demand.email,
      :subject => "New Account Created: #{@demand.service}"
    )
  end

end

