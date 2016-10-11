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

  before_filter :login_required,      :except => [:show, :new, :create, :edit, :destroy, :update, :confirm, :resend_confirm]
  before_filter :admin_role_required, :except => [:show, :new, :create, :edit, :destroy, :update, :confirm, :resend_confirm]


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
    @signup = Signup.new(params[:signup])
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
      flash[:error] = "It seems some error occured. Email notification was probably not sent.\n"
    end

    send_admin_notification(@signup)

    sleep 1
    redirect_to :action => :show, :id => @signup.id
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

    @signup.update_attributes(params[:signup])

    if ! @signup.save
      render :action => :new
      return
    end

    flash[:notice] = "The account request has been updated."

    sleep 1
    redirect_to :action => :show, :id => @signup.id
  end



  def index #:nodoc:
    @scope = scope_from_session('signups')

    scope_default_order(@scope, 'country')

    @base_scope       = Signup.where({})
    @signups          = @scope.apply(@base_scope)

    # Prepare the Pagination object
    @scope.pagination ||= Scope::Pagination.from_hash({ :per_page => 25 })
    @current_offset = (@scope.pagination.page - 1) * @scope.pagination.per_page

    scope_to_session(@scope, 'signups')

    respond_to do |format|
      format.js
      format.html # index.html.erb
    end

  end



  def destroy #:nodoc:
    @signup = Signup.find(params[:id]) rescue nil

    unless can_edit?(@signup)
      redirect_to login_path
      return
    end

    @signup.destroy
    flash[:notice] = "The account request has been deleted."

    redirect_to :action => :index
  end


  # Confirms that a signup person's email address actually belongs to them
  def confirm #:nodoc:
    @signup = Signup.find(params[:id]) rescue nil
    token    = params[:token] || ""
    if @signup.present? && token.present? && @signup.confirm_token == token
      @signup.confirmed = true
      @signup.save
    else
      redirect_to login_path
    end
  end



  # Administrator action that converts a signup into a user
  def approve
    @signup = Signup.find(params[:id]) rescue nil

    unless can_edit?(@signup)
      flash[:error] = "Could not approve account"
      redirect_to login_path
      return
    end

    if @signup.login.blank?
      flash[:error] = "Before approval, a 'login' name must be set."
      redirect_to :action => :edit, :id => @signup.id
      return
    end

    symbolic_result, @info, @exception_trace = approve_one(@signup)

    if symbolic_result == :all_ok
      # flash.now[:notice] = "The account request for '#{@signup.full}' has been approved."
      # flash.now[:notice] += "\nThe user was notified of his or her new account."
      current_user.addlog_context(self,"Approved account request for user '#{@signup.login}'")
      User.find_by_login(@signup.login).addlog_context(self, "Account created after request approved by '#{current_user.login}'")
    elsif symbolic_result == :failed_save
      # flash.now[:error] = @info.presence || ""
    elsif symbolic_result == :failed_approval
      # flash.now[:error] = @info.presence || ""
    elsif symbolic_result == :not_notifiable
      # flash.now[:error] = @info.presence || ""
      @current_user.addlog_context(self,"Approved account request for user '#{@signup.login}'")
      User.find_by_login(@signup.login).addlog_context(self, "Account created after request approved by '#{@current_user.login}'")
    end

  end



  def multi_action #:nodoc:
    if params[:commit] =~ /Approve/
      return approve_multi
    end

    if params[:commit] =~ /Fix Login/
      return fix_login_multi
    end

    if params[:commit] =~ /Resend/
      return resend_conf_multi
    end

    if params[:commit] =~ /Delete/
      return delete_multi
    end

    redirect_to :action => :index
  end



  def delete_multi #:nodoc:
    reqids = params[:reqids] || []
    reqs = Signup.find(reqids)

    count = 0
    reqs.each do |req|
      count += 1 if req.destroy
    end

    flash[:notice] = "Deleted " + view_pluralize(count, "record") + "."

    redirect_to :action => :index
  end



  def fix_login_multi #:nodoc:
    reqids = params[:reqids] || []
    reqs = Signup.find(reqids)

    @results = reqs.map do |req|

      old   = req.login

      new   = ""
      puts "Fixing: #{old}"

      email = req.email
      if email =~ /\A(\w+)@/
        new = Regexp.last_match[1].downcase
      end
      new = "" if new.size < 3 || new.size > 8

      if new.blank?
        new = (req.first[0,1] + req.last[0,7]).downcase
      end
      new = "" if new !~ /\A[a-z][a-zA-Z0-9]+\z/
      new = "" if new.size < 3 || new.size > 8

      if new.blank? || !req.login.blank?
          puts "  -> No changes"
        [ req, :no_change, 'No changes', nil ]
      else
        backtrace = nil
        begin
          req.update_attribute(:login, new)
          puts "  -> #{old} => #{new}"
        rescue => ex
          backtrace = ex.backtrace
        end
        message = backtrace ? "Attempted" : "Adjusted"
        [ req, :adjusted, "#{message}: #{old} => #{new}", backtrace ]
      end

    end

    @results.compact!

    render :action => :multi_action
  end



  def resend_conf_multi #:nodoc:
    reqids = params[:reqids] || []
    reqs = Signup.find(reqids)

    count = 0

    @results = reqs.map do |req|
      next if req.confirmed? || req.approved_by.present?
      print "Resending confirmation: #{req.full_name}"
      if send_confirm_email(req)
        count += 1
        [ req, :all_ok, "Resent confirmation email", nil ]
      else
        puts "=> ********* FAILED *********"
        [ req, :failed_confirm, "ERROR: Could not send confirmation email", nil ]
      end
    end

    @results.compact!

    flash[:notice] = "Sent " + view_pluralize(count, "confirmation email") + "."
    render :action => :multi_action
  end



  def approve_multi #:nodoc:
    reqids = params[:reqids] || []
    reqs = Signup.find(reqids)

    @results = reqs.map do |req|
      print "Approving: #{req.full_name} => "
      symbolic_result, message, backtrace = approve_one(req)

      #message = "Account created and user notified" if message.blank? && symbolic_result == :all_ok
      [ req, symbolic_result, message, backtrace ]
    end

    @results.compact!

    render :action => :multi_action
  end



  def approve_one(req) #:nodoc:
    result = nil
    exception_trace = ""

    # Trigger approval code
    if req.respond_to?(:after_approval)
      begin
        result = req.after_approval
      rescue => ex
        exception_trace = "#{ex.class}: #{ex.message}\n" + ex.backtrace.join("\n")
        return [ :failed_approval, 'ERROR: Exception when approving' , exception_trace ]
      end
    end

    return [ :failed_save, "ERROR: #{result.diagnostics}", nil ] unless result.success

    # Mark as approved
    info           = result.diagnostics    rescue nil
    plain_password = result.plain_password rescue nil

    req.approved_by ||= current_user.login
    req.approved_at ||= Time.now
    req.save

    # Notify user
    if send_account_created_email(req,plain_password)
      return [ :all_ok, info, nil ]
    else
      return [ :not_notifiable, 'ERROR: The User was created in CBRAIN, but the notification email failed to send.', 'ERROR: The User was created in CBRAIN, but the notification email failed to send.' ]
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
      flash[:error] = "It seems some error occured. Email notification was probably not sent. Check your mailhost settings.\n"
    end

    sleep 1
    redirect_to :action => :show, :id => @signup.id
  end



  private



  def can_edit?(signup) #:nodoc:
    return false if signup.blank?
    return true  if signup[:session_id] == request.session_options[:id]
    if !current_user.nil?
      return true  if current_user.has_role?(:admin_user)
    end
    false
  end



  def send_confirm_email(signup) #:nodoc:
    confirm_url = url_for(:controller => :signups, :action => :confirm, :id => signup.id, :only_path => false, :token => signup.confirm_token)
    CbrainMailer.signup_request_confirmation(signup, confirm_url).deliver
    return true
  rescue => ex
    Rails.logger.error ex.to_s
    #flash[:error] = "It seems some error occured. Email notification was probably not sent. Sorry. We'll look into that.\n"
    return false
  end



  def send_account_created_email(signup, plain_password = nil) #:nodoc:
    CbrainMailer.signup_account_created(signup, plain_password).deliver
    return true
  rescue => ex
    Rails.logger.error ex.to_s
    #flash.now[:error] ||= "No email for records: "
    #flash.now[:error]  += "#{signup.id} (#{ex.class.to_s}), "
    return false
  end



  def send_admin_notification(signup) #:nodoc:
    return unless RemoteResource.current_resource.support_email
    show_url  = url_for(:controller => :signups, :action => :show, :id => signup.id, :only_path => false)
    CbrainMailer.signup_notify_admin(signup, show_url).deliver
    return true
  rescue => ex
    Rails.logger.error ex.to_s
    #flash[:error] = "It seems some error occured. Email notification was probably not sent. Sorry. We'll look into that."
    return false
  end

end

