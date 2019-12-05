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

class SignupsController < ApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  before_action :login_required,      :except => [:show, :new, :create, :edit, :destroy, :update, :confirm, :resend_confirm]
  before_action :admin_role_required, :except => [:show, :new, :create, :edit, :destroy, :update, :confirm, :resend_confirm]

  ################################################################
  # User-accessible action (do not need to be logged in)
  ################################################################

  def show #:nodoc:
    @signup = Signup.find(params[:id]) rescue nil

    unless can_edit?(@signup)
      redirect_to login_path
      return
    end
  end

  def new #:nodoc:
    @signup = Signup.new
  end

  def create #:nodoc:
    @signup = Signup.new(signup_params)
    @signup.session_id = request.session_options[:id]
    @signup.generate_token

    unless can_edit?(@signup)
      redirect_to login_path
      return
    end

    if ! @signup.save
      render :action => :new
      return
    end

    unless send_confirm_email(@signup)
      flash[:error] = "It seems some error occurred. The email notification was probably not sent. There's nothing we can do about this."
    end

    send_admin_notification(@signup)

    sleep 1
    redirect_to signup_path(@signup)
  end

  def edit #:nodoc:
    @signup = Signup.find(params[:id]) rescue nil

    unless can_edit?(@signup)
      redirect_to login_path
      return
    end

    render :action => :new
  end

  def update #:nodoc:
    @signup = Signup.find(params[:id]) rescue nil

    unless can_edit?(@signup)
      redirect_to login_path
      return
    end

    @signup.update_attributes(signup_params)

    if ! @signup.save
      render :action => :new
      return
    end

    flash[:notice] = "The account request has been updated."

    sleep 1
    redirect_to signup_path(@signup)
  end

  def destroy #:nodoc:
    @signup = Signup.find(params[:id]) rescue nil

    unless can_edit?(@signup)
      redirect_to login_path
      return
    end

    @signup.destroy
    flash[:notice] = "The account request has been deleted."

    if current_user && current_user.has_role?(:admin_user)
      redirect_to signups_path
    else
      redirect_to login_path
    end
  end

  # Confirms that a signup person's email address actually belongs to them
  def confirm #:nodoc:
    @signup = Signup.find(params[:id]) rescue nil
    token    = params[:token] || ""

    # Params properly confirms the request? Then record that and show a nice message to user.
    if @signup.present? && token.present? && @signup.confirm_token == token
      @signup.confirmed = true
      @signup.save
      @propose_view = can_edit?(@signup)
      return # renders confirm.html.erb
    end

    # If not, bluntly send user back to someplace else.
    if current_user && current_user.has_role?(:admin_user)
      redirect_to signups_path
    else
      redirect_to login_path
    end
  end

  def resend_confirm #:nodoc:
    @signup = Signup.find(params[:id]) rescue nil

    unless can_edit?(@signup)
      redirect_to login_path
      return
    end

    if send_confirm_email(@signup)
      flash[:notice] = "A new confirmation email has been sent."
    else
      flash[:error] = "It seems some error occurred. Email notification was probably not sent. Try again later, or contact the admins."
    end

    sleep 1
    redirect_to signup_path(@signup)
  end

  ################################################################
  # Admin Actions; the current_user must be signed in as an admin.
  ################################################################

  def index #:nodoc:
    @scope = scope_from_session

    scope_default_order(@scope, 'created_at', :desc)

    # Maintains show/hide hidden records option in session.
    view_hidden                 = @scope.custom[:view_hidden].present?
    view_hidden                 = ( params[:view_hidden].presence == "true" ) if params[:view_hidden].present?
    @scope.custom[:view_hidden] = view_hidden

    @base_scope                 = Signup.where(nil)
    @view_scope                 = @scope.apply(@base_scope)
    @num_hidden                 = view_hidden ? 0 : @view_scope.where(:hidden => true).count
    @view_scope                 = @view_scope.where(:hidden => false) unless view_hidden

    # Prepare the Pagination object
    @scope.pagination           ||= Scope::Pagination.from_hash({ :per_page => 25 })

    @signups                    = @scope.pagination.apply(@view_scope)

    scope_to_session(@scope)

    respond_to do |format|
      format.js
      format.html
    end
  end

  # Main entry point for mass operations on requests.
  # Some of these methods render the multi_action view,
  # which expects @results to be an array of quadruplets
  # [ signup, status, message, backtrace ]
  # where +signup+ is a Signup object.
  def multi_action #:nodoc:
    if params[:commit] =~ /Login/i
      return fix_login_multi
    end

    if params[:commit] =~ /Resend/i
      return resend_conf_multi
    end

    if params[:commit] =~ /Delete/i
      return delete_multi
    end

    if params[:commit] =~ /Toggle/i
      return toggle_multi
    end

    # Default: unknown multi action?
    redirect_to signups_path
  end

  def delete_multi #:nodoc:
    reqids = params[:reqids] || []
    reqs   = Signup.find(reqids)

    count = 0
    reqs.each do |req|
      count += 1 if req.destroy
    end

    flash[:notice] = "Deleted " + view_pluralize(count, "record") + "."

    redirect_to signups_path
  end

  # Changes login attribute into:
  # first letter of first name + last name (e.g. "tjones")
  def fix_login_multi #:nodoc:
    reqids = params[:reqids] || []
    reqs   = Signup.find(reqids)

    @results = reqs.map do |req|
      next if req.approved? # don't mess with already approved records
      old = req.login
      new = (req.first[0,1] + req.last).downcase.gsub(/\W+/,"")

      backtrace = nil
      begin
        req.update_attribute(:login, new)
      rescue => ex
        backtrace = ex.backtrace
      end
      message = backtrace ? "Attempted" : "Adjusted"
      [ req, :adjusted, "#{message}: '#{old}' => '#{new}'", backtrace ]
    end

    @results.compact!

    render :action => :multi_action
  end

  def resend_conf_multi #:nodoc:
    reqids = params[:reqids] || []
    reqs   = Signup.find(reqids)

    count = 0

    @results = reqs.map do |req|
      next if req.confirmed? || req.approved?
      if send_confirm_email(req)
        count += 1
        [ req, :all_ok, "Resent confirmation email", nil ]
      else
        [ req, :failed_confirm, "ERROR: Could not send confirmation email", nil ]
      end
    end

    @results.compact!

    flash[:notice] = "Sent " + view_pluralize(count, "confirmation email") + "."
    render :action => :multi_action
  end

  def toggle_multi #:nodoc:
    reqids = params[:reqids] || []
    reqs   = Signup.find(reqids)

    newly_hidden = reqs.select do |req|
      req.hidden = ! req.hidden?
      req.save
      req.hidden?
    end

    revealed = reqs.count - newly_hidden.count

    flash[:notice] ||= ""
    flash[:notice]  += "Hidden "   + view_pluralize(newly_hidden.count, "record") + "\n" if newly_hidden.count > 0
    flash[:notice]  += "Revealed " + view_pluralize(revealed,           "record") + "\n" if revealed           > 0

    redirect_to signups_path
  end

  private

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

  def send_confirm_email(signup) #:nodoc:
    confirm_url = url_for(:controller => :signups, :action => :confirm, :id => signup.id, :only_path => false, :token => signup.confirm_token)
    CbrainMailer.signup_request_confirmation(signup, confirm_url).deliver
    return true
  rescue => ex
    Rails.logger.error ex.to_s
    return false
  end

  def send_account_created_email(user, plain_password) #:nodoc:
    CbrainMailer.registration_confirmation(user, plain_password).deliver
    return true
  rescue => ex
    Rails.logger.error ex.to_s
    return false
  end

  def send_admin_notification(signup) #:nodoc:
    return unless RemoteResource.current_resource.support_email
    show_url  = url_for(:controller => :signups, :action => :show, :id => signup.id, :only_path => false)
    CbrainMailer.signup_notify_admin(signup, show_url).deliver
    return true
  rescue => ex
    Rails.logger.error ex.to_s
    return false
  end

end

