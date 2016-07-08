
require 'cbrain_ruby_api'

class DemandsController < ApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  include DemandsHelper
  #before_filter :admin_role_required, :except => [:show, :new, :create, :edit, :update, :confirm]

  def show
    @demand = Demand.find(params[:id]) rescue nil
    unless can_edit?(@demand)
      redirect_to :action => :new
      return
    end
  end



  def new
    @demand = Demand.new
  end



  def create
    @demand = Demand.new(params[:demand])
    @demand.session_id = session[:session_id]
    @demand.generate_token

    unless can_edit?(@demand)
      redirect_to :action => :new
      return
    end

    if ! @demand.save
      render :action => :new
      return
    end

    unless send_confirm_email(@demand)
      flash[:error] = "It seems some error occured. Email notification was probably not sent. Sorry. We'll look into that.\n"
    end

    send_admin_notification(@demand)

    sleep 1
    redirect_to :action => :show, :id => @demand.id
  end



  def edit
    @demand = Demand.find(params[:id]) rescue nil
    unless can_edit?(@demand)
      redirect_to :action => :new
      return
    end
    render :action => :new
  end



  def update
    @demand = Demand.find(params[:id]) rescue nil

    unless can_edit?(@demand)
      redirect_to :action => :new
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



  def index
    @page_size = (params[:page_size].presence || session[:page_size]     || 100).to_i
    session[:page_size] = @page_size

    @page      = (params[:page].presence      || session[:page].presence || "1").to_i
    @real_tot  = Demand.count

    session[:institution_filter] = params[:institution_filter] if params.has_key?(:institution_filter)
    session[:email_filter]       = params[:email_filter]       if params.has_key?(:email_filter)
    session[:login_filter]       = params[:login_filter]       if params.has_key?(:login_filter)
    session[:country_filter]     = params[:country_filter]     if params.has_key?(:country_filter)
    session[:approved_filter]    = params[:approved_filter]    if params.has_key?(:approved_filter)
    session[:confirmed_filter]   = params[:confirmed_filter]   if params.has_key?(:confirmed_filter)
    session[:dupemail_filter]    = params[:dupemail_filter]    if params.has_key?(:dupemail_filter)

    @demands = Demand.where({})
    @demands = @demands.where(["institution like ?", "%#{session[:institution_filter]}%"]) if session[:institution_filter].present?
    @demands = @demands.where(["email like ?",       "%#{session[:email_filter]}%"])       if session[:email_filter].present?
    @demands = @demands.where(["login like ?",       "%#{session[:login_filter]}%"])       if session[:login_filter].present?
    @demands = @demands.where(["country like ?",     "%#{session[:country_filter]}%"])     if session[:country_filter].present?
    @demands = @demands.where("approved_by is not null")                            if session[:approved_filter] == "1"
    @demands = @demands.where(:approved_by => nil)                                  if session[:approved_filter] == "0"
    @demands = @demands.where("confirmed is not null")                              if session[:confirmed_filter] == "1"
    @demands = @demands.where(:confirmed => nil)                                    if session[:confirmed_filter] == "0"

    if session[:dupemail_filter].present?
       dup_emails = []
       Demand.select(:email).group(:email).count(:email).each { |e,c| dup_emails.push(e) if c > 1 }
       @demands = @demands.where(:email => dup_emails) if dup_emails.size > 0
       @demands = @demands.order([ :email, :id ])
    end

    @tot     = @demands.count

    @page    = 1 if (@page-1) * @page_size > @tot
    @demands = @demands.offset((@page-1) * @page_size).limit(@page_size).all

    session[:page]               = @page.to_s

  end



  def destroy
    @demand = Demand.find(params[:id]) rescue nil

    unless can_edit?(@demand)
      redirect_to :action => :new
      return
    end

    @demand.destroy
    flash[:notice] = "The account request has been deleted."

    if admin_user_logged_in?
      redirect_to :action => :index
    else
      redirect_to :action => :new
    end
  end



  def confirm
    @demand = Demand.find(params[:id]) rescue nil
    token    = params[:token] || ""
    if @demand.present? && token.present? && @demand.confirm_token == token
      @demand.confirmed = true
      @demand.save
    else
      redirect_to :root
    end
  end



  def approve
    @demand = Demand.find(params[:id]) rescue nil

    unless can_edit?(@demand) && admin_user_logged_in?
      flash[:error] = "Could not approve account"
      redirect_to :action => :new
      return
    end

    if @demand.login.blank?
      flash[:error] = "Before approval, a 'login' name must be set."
      redirect_to :action => :edit, :id => @demand.id
      return
    end

    symbolic_result, @info, @exception_trace = approve_one(@demand)

    if symbolic_result == :all_ok
      flash.now[:notice] = "The after_approval callback was successfully invoked."
      flash.now[:notice] += "\nThe account request for '#{@demand.full}' has been approved."
      flash.now[:notice] += "\nThe user was notified of his new account."
    elsif symbolic_result == :failed_approval
      flash.now[:error] = @info.presence || ""
    elsif symbolic_result == :failed_undo_approval
      flash.now[:error] = @info.presence || ""
    elsif symbolic_result == :not_notifiable
      flash.now[:error] = @info.presence || ""
    end

  end



  def multi_action

    if params[:commit] =~ /approve/i
      return approve_multi
    end

    if params[:commit] =~ /fix login/i
      return fix_login_multi
    end

    if params[:commit] =~ /resend/i
      return resend_conf_multi
    end

    if params[:commit] =~ /clean not notified/i
      return clean_not_notified_multi
    end

    if params[:commit] =~ /delete/i
      return delete_multi
    end

    if params[:commit] =~ /undo approval/i
      return undo_app_multi
    end

    redirect_to :action => :index
  end



  def delete_multi

    reqids = params[:del_reqids] || []
    reqs = Demand.find(reqids)

    count = 0
    reqs.each do |req|
      count += 1 if req.destroy
    end

    flash[:notice] = "Deleted #{count} records."

    redirect_to :action => :index
  end



  def undo_app_multi

    reqids = params[:undoapp_reqids] || []
    reqs = Demand.find(reqids)

    # TODO: optimize whole process when no undo_approval() method

    @results = reqs.map do |req|
      next unless req.account_exists?
      next unless req.approved?

      puts "Undoing approval for account: #{req.full_name}"

      if req.respond_to?(:undo_approval)
        begin
          if req.undo_approval
            req.approved_by = nil
            req.approved_at = nil
            req.save
            [ req, :all_ok, 'Undid approval.', nil ]
          else
            [ req, :failed, 'Did not undo approval.', nil ]
          end
        rescue => ex
          exception_trace = "#{ex.class}: #{ex.message}\n" + ex.backtrace.join("\n")
          [ req, :failed_unapproving_account, 'ERROR: Exception when un-approving account' , exception_trace ]
        end
      else
        [ req, :no_operation, 'Warning: No support for un-approving.', nil ]
      end

    end

    @results.compact!

    render :action => :multi_action
  end



  def clean_not_notified_multi

    reqids = params[:notnotif_reqids] || []
    reqs = Demand.find(reqids)

    # TODO: optimize whole process when no after_failed_user_notification() method

    @results = reqs.map do |req|
      next unless req.account_exists?
      next if     req.approved?

      puts "Cleaning account: #{req.full_name}"

      if req.respond_to?(:after_failed_user_notification)
        begin
          req.after_failed_user_notification
          [ req, :all_ok, 'Record cleaned.', nil ]
        rescue => ex
          exception_trace = "#{ex.class}: #{ex.message}\n" + ex.backtrace.join("\n")
          [ req, :failed_cleaning_account, 'ERROR: Exception when cleaning account' , exception_trace ]
        end
      else
        [ req, :no_operation, 'Warning: No support for cleaning.', nil ]
      end

    end

    @results.compact!

    render :action => :multi_action
  end



  def resend_conf_multi

    reqids = params[:notconf_reqids] || []
    reqs = Demand.find(reqids)

    @results = reqs.map do |req|
      next if req.confirmed? || req.approved_by.present?
      print "Resending confirmation: #{req.full_name}"
      if send_confirm_email(req)
        puts ""
        [ req, :all_ok, "Resend confirmation email", nil ]
      else
        puts "=> ********* FAILED *********"
        [ req, :failed_confirm, "ERROR: Could not send confirmation email", nil ]
      end
    end

    @results.compact!

    render :action => :multi_action
  end



  def fix_login_multi

    reqids = params[:log_reqids] || []
    reqs = Demand.find(reqids)

    login_cnts = Demand.uniq_login_cnts

    @results = reqs.map do |req|

      old   = req.login
      new   = ""
      puts "Fixing: #{old}"

      email = req.email
      if email =~ /^(\w+)@/
        new = Regexp.last_match[1].downcase
      end
      new = "" if new.size < 3 || new.size > 8
      new = "" if (login_cnts[new] || 0) > 0

      if new.blank?
        new = (req.first[0,1] + req.last[0,7]).downcase
      end
      new = "" if new !~ /^[a-z][a-zA-Z0-9]+$/
      new = "" if new.size < 3 || new.size > 8
      new = "" if (login_cnts[new] || 0) > 0

      if new.blank?
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



  def approve_multi

    reqids = params[:app_reqids] || []
    reqs = Demand.find(reqids)

    @results = reqs.map do |req|
      print "Approving: #{req.full_name} => "
      symbolic_result, message, backtrace = approve_one(req)
      puts symbolic_result.to_s
      #message = "Account created and user notified" if message.blank? && symbolic_result == :all_ok
      [ req, symbolic_result, message, backtrace ]
    end

    @results.compact!

    render :action => :multi_action
  end



  def approve_one(req)
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

    # Mark as approved
    info           = result.diagnostics    rescue nil
    plain_password = result.plain_password rescue nil

    req.approved_by ||= current_user
    req.approved_at ||= Time.now
    req.save

    # Notify user
    if send_account_created_email(req,plain_password)
      return [ :all_ok, info, nil ]
    end

    # Undo approval (user not notified)
    req.approved_by = nil
    req.approved_at = nil
    req.save

    if req.respond_to?(:after_failed_user_notification)
      begin
        req.after_failed_user_notification
      rescue => ex
        exception_trace = "#{ex.class}: #{ex.message}\n" + ex.backtrace.join("\n")
        return [ :failed_undo_approval, 'ERROR: Exception when undoing approval' , exception_trace ]
      end
    end

    return [ :not_notifiable, 'ERROR: Could not notify user', nil ]
  end



  def resend_confirm
    @demand = Demand.find(params[:id]) rescue nil

    unless can_edit?(@demand)
      redirect_to :action => :new
      return
    end

    if send_confirm_email(@demand)
      flash[:notice] = "A new confirmation email has been sent."
    else
      flash[:error] = "It seems some error occured. Email notification was probably not sent. Sorry. We'll look into that.\n"
    end

    sleep 1
    redirect_to :action => :show, :id => @demand.id
  end



  private



  def can_edit?(demand)
    return false if demand.blank?
    return true  if admin_user_logged_in?
    return true  if demand[:session_id] == session[:session_id]
    false
  end



  def send_confirm_email(demand)
    confirm_url = url_for(:controller => :demands, :action => :confirm, :id => demand.id, :only_path => false, :token => demand.confirm_token)
    ConfirmMailer.request_confirmation(demand, confirm_url).deliver
    return true
  rescue => ex
    Rails.logger.error ex.to_s
    #flash[:error] = "It seems some error occured. Email notification was probably not sent. Sorry. We'll look into that.\n"
    return false
  end



  def send_account_created_email(demand, plain_password = nil)
    ConfirmMailer.account_created(demand, plain_password).deliver
    return true
  rescue => ex
    Rails.logger.error ex.to_s
    #flash.now[:error] ||= "No email for records: "
    #flash.now[:error]  += "#{demand.id} (#{ex.class.to_s}), "
    return false
  end



  def send_admin_notification(demand)
    return if NewAccountOfferings::AdminNotificationEmail.blank?
    show_url  = url_for(:controller => :demands, :action => :show, :id => demand.id, :only_path => false)
    ConfirmMailer.notify_admin(demand, show_url).deliver
    return true
  rescue => ex
    Rails.logger.error ex.to_s
    #flash[:error] = "It seems some error occured. Email notification was probably not sent. Sorry. We'll look into that."
    return false
  end

end

