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

class DemandsController < ApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  before_filter :login_required,      :except => [:show, :new, :create, :edit, :destroy, :update, :confirm, :resend_confirm]
  before_filter :admin_role_required, :except => [:show, :new, :create, :edit, :destroy, :update, :confirm, :resend_confirm]


  def show #:nodoc:
    @demand = Demand.find(params[:id]) rescue nil
    unless can_edit?(@demand)
      redirect_to '/login'
      return
    end
  end



  def new #:nodoc:
    @demand = Demand.new
  end



  def create #:nodoc:
    @demand = Demand.new(params[:demand])
    @demand.session_id = request.session_options[:id]
    @demand.generate_token

    unless can_edit?(@demand)
      redirect_to '/login'
      return
    end

    if ! @demand.save
      render :action => :new
      return
    end

    unless send_confirm_email(@demand)
      flash[:error] = "It seems some error occured. Email notification was probably not sent.\n"
    end

    send_admin_notification(@demand)

    sleep 1
    redirect_to :action => :show, :id => @demand.id
  end



  def edit #:nodoc:
    @demand = Demand.find(params[:id]) rescue nil
    unless can_edit?(@demand)
      redirect_to '/login'
      return
    end
    render :action => :new
  end



  def update #:nodoc:
    @demand = Demand.find(params[:id]) rescue nil

    unless can_edit?(@demand)
      redirect_to '/login'
      return
    end

    @demand.update_attributes(params[:demand])

    if ! @demand.save
      render :action => :new
      return
    end

    flash[:notice] = "The account request has been updated."

    sleep 1
    redirect_to :action => :show, :id => @demand.id
  end



  def index #:nodoc:
    @scope = scope_from_session('demands')

    scope_default_order(@scope, 'country')

    @base_scope       = Demand.where({})
    @demands          = @scope.apply(@base_scope)

    # Prepare the Pagination object
    @scope.pagination ||= Scope::Pagination.from_hash({ :per_page => 25 })
    @current_offset = (@scope.pagination.page - 1) * @scope.pagination.per_page

    scope_to_session(@scope, 'demands')

    respond_to do |format|
      format.js
      format.html # index.html.erb
    end

  end



  def destroy #:nodoc:
    @demand = Demand.find(params[:id]) rescue nil

    unless can_edit?(@demand)
      redirect_to '/login'
      return
    end

    @demand.destroy
    flash[:notice] = "The account request has been deleted."

    redirect_to :action => :index
  end


  # Confirms that a demandee's email address actually belongs to them
  def confirm #:nodoc:
    @demand = Demand.find(params[:id]) rescue nil
    token    = params[:token] || ""
    if @demand.present? && token.present? && @demand.confirm_token == token
      @demand.confirmed = true
      @demand.save
    else
      redirect_to '/login'
    end
  end


  # Administrator action that converts a demand into a user
  def approve
    @demand = Demand.find(params[:id]) rescue nil

    unless can_edit?(@demand)
      flash[:error] = "Could not approve account"
      redirect_to '/login'
      return
    end

    if @demand.login.blank?
      flash[:error] = "Before approval, a 'login' name must be set."
      redirect_to :action => :edit, :id => @demand.id
      return
    end

    symbolic_result, @info, @exception_trace = approve_one(@demand)

    if symbolic_result == :all_ok
      # flash.now[:notice] = "The account request for '#{@demand.full}' has been approved."
      # flash.now[:notice] += "\nThe user was notified of his or her new account."
      current_user.addlog_context(self,"Approved account request for user '#{@demand.login}'")
      User.find_by_login(@demand.login).addlog_context(self, "Account created after request approved by '#{current_user.login}'")
    elsif symbolic_result == :failed_save
      # flash.now[:error] = @info.presence || ""
    elsif symbolic_result == :failed_approval
      # flash.now[:error] = @info.presence || ""
    elsif symbolic_result == :not_notifiable
      # flash.now[:error] = @info.presence || ""
      @current_user.addlog_context(self,"Approved account request for user '#{@demand.login}'")
      User.find_by_login(@demand.login).addlog_context(self, "Account created after request approved by '#{@current_user.login}'")
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
    reqs = Demand.find(reqids)

    count = 0
    reqs.each do |req|
      count += 1 if req.destroy
    end

    flash[:notice] = "Deleted " + view_pluralize(count, "record") + "."

    redirect_to :action => :index
  end



  def fix_login_multi #:nodoc:
    reqids = params[:reqids] || []
    reqs = Demand.find(reqids)

    @results = reqs.map do |req|

      old   = req.login
      if old =~ /\A[a-z][a-zA-Z0-9]+\z/ && old.size > 3 && old.size < 40
        login_valid = true
      else
        login_valid = false
      end

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

      if new.blank? || login_valid
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
    reqs = Demand.find(reqids)

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
    reqs = Demand.find(reqids)

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
    @demand = Demand.find(params[:id]) rescue nil

    unless can_edit?(@demand)
      redirect_to '/login'
      return
    end

    if send_confirm_email(@demand)
      flash[:notice] = "A new confirmation email has been sent."
    else
      flash[:error] = "It seems some error occured. Email notification was probably not sent. Check your mailhost settings.\n"
    end

    sleep 1
    redirect_to :action => :show, :id => @demand.id
  end



  private



  def can_edit?(demand) #:nodoc:
    return false if demand.blank?
    return true  if demand[:session_id] == request.session_options[:id]
    if !current_user.nil?
      return true  if current_user.has_role?(:admin_user)
    end
    false
  end



  def send_confirm_email(demand) #:nodoc:
    confirm_url = url_for(:controller => :demands, :action => :confirm, :id => demand.id, :only_path => false, :token => demand.confirm_token)
    CbrainMailer.request_confirmation(demand, confirm_url).deliver
    return true
  rescue => ex
    Rails.logger.error ex.to_s
    #flash[:error] = "It seems some error occured. Email notification was probably not sent. Sorry. We'll look into that.\n"
    return false
  end



  def send_account_created_email(demand, plain_password = nil) #:nodoc:
    CbrainMailer.account_created(demand, plain_password).deliver
    return true
  rescue => ex
    Rails.logger.error ex.to_s
    #flash.now[:error] ||= "No email for records: "
    #flash.now[:error]  += "#{demand.id} (#{ex.class.to_s}), "
    return false
  end



  def send_admin_notification(demand) #:nodoc:
    return unless RemoteResource.current_resource.support_email
    show_url  = url_for(:controller => :demands, :action => :show, :id => demand.id, :only_path => false)
    CbrainMailer.notify_admin(demand, show_url).deliver
    return true
  rescue => ex
    Rails.logger.error ex.to_s
    #flash[:error] = "It seems some error occured. Email notification was probably not sent. Sorry. We'll look into that."
    return false
  end

end

