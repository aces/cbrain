
#
# NeuroHub Project
#
# Copyright (C) 2020
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

require 'ipaddr'

class NhSignupsController < NeurohubApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  before_action :login_required, :except => [:new, :create, :show, :confirm]

  spurious_params_ban_ip :new, :show, :confirm => [ :token ]

  def new #:nodoc:
    @signup = Signup.new
  end

  def show #:nodoc:
  end

  def create #:nodoc:
    @signup                    = Signup.new(signup_params)
    @signup.session_id         = request.session_options[:id]
    @signup.remote_resource_id = RemoteResource.current_resource.id
    @signup.form_page          = 'NeuroHub' # Just a keyword that IDs the signup page
    @signup.generate_token

    # Bulletproof code to extract the timestamp of the form in the
    # obfuscated 'auth_spec' parameter
    form_generated_at_s   = params[:auth_spec].presence || Time.now.to_i.to_s
    form_generated_at_int = form_generated_at_s.to_i rescue Time.now.to_i
    form_generated_at     = Time.at(form_generated_at_int)
    # If form was generated less then 10 seconds ago, ban the IP address
    return ban_ip("Signup form filled too quickly") if @signup.email.present? && (Time.now - form_generated_at < 10.0)

    unless can_edit?(@signup)
      # this check is probably just a precation
      flash[:error] = 'Errors occurred, please try again.'
      redirect_to signin_path
      return
    end

    if ! @signup.save
      @auth_spec = form_generated_at_int # keep old form_generated time
      flash.now[:error] = 'We are not able to accept your request.'
      render :action => :new
      return
    end

    unless send_nh_confirm_email(@signup)
      flash[:error] = "It seems some error occurred. The email notification was probably not sent. There's nothing we can do about this."
    end

    send_admin_notification(@signup)

    sleep 1
    flash[:notice] = "Success!"
    redirect_to nh_signup_path(@signup)
  end

  # Confirms that a signup person's email address actually belongs to them
  def confirm #:nodoc:
    @signup = Signup.find(params[:id]) rescue nil
    token   = params[:token] || ""

    # Params properly confirms the request? Then record that and show a nice message to user.
    if @signup.present? && token.present? && @signup.confirm_token == token
      @signup.confirmed = true
      @signup.save
      return # renders confirm.html.erb
    end

    # If not, bluntly send user back to someplace else.
    if current_user && current_user.has_role?(:admin_user)
      redirect_to signups_path
    else
      redirect_to login_path
    end
  end

  def signup_params
    params.require(:signup).permit(
      :title, :first, :middle, :last,
      :institution, :department, :position, :affiliation, :email,
      :street1, :street2, :city, :province, :country, :postal_code,
      :login, :time_zone, :comment, :admin_comment, :hidden, :user_id
    )
  end

  def can_edit?(signup) #:nodoc:
    return false if signup.blank?
    return true  if signup[:session_id] == request.session_options[:id]
    return true  if current_user && current_user.has_role?(:admin_user)
    false
  end

  private

  def send_nh_confirm_email(signup) #:nodoc:
    confirm_url = url_for(:controller => :nh_signups, :action => :confirm, :id => signup.id, :only_path => false, :token => signup.confirm_token)
    signup.action_mailer_class.signup_request_confirmation(signup, confirm_url).deliver
    return true
  rescue => ex
    Rails.logger.error ex.to_s
    return false
  end

  def send_admin_notification(signup) #:nodoc:
    return unless RemoteResource.current_resource.support_email
    show_url  = url_for(:controller => :signups, :action => :show, :id => signup.id, :only_path => false)
    signup.action_mailer_class.signup_notify_admin(signup, show_url).deliver
    return true
  rescue => ex
    Rails.logger.error ex.to_s
    return false
  end

end
