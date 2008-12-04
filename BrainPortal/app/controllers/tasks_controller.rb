
#
# CBRAIN Project
#
# Task controller for the BrainPortal interface
#
# Original author: Pierre Rioux
#
# $Id$
#

class TasksController < ApplicationController

  Revision_info="$Id$"

  before_filter :login_required
  
  def index
    if current_user.login == "admin"
      @tasks = DrmaaTask.find(:all)
    else
      @tasks = DrmaaTask.find(:all, :params => { :user_id => current_user.id } )
    end
  end

  # GET /tasks/1
  # GET /tasks/1.xml
  def show
    @task = DrmaaTask.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @task }
    end

  rescue
    access_error("Task doesn't exist or you do not have permission to access it.", 404)

  end

  def operation

    operation   = params[:operation]
    tasklist    = params[:tasklist] || []

    flash[:error]  ||= ""
    flash[:notice] ||= ""

    if operation.nil? || operation.empty?
       flash[:notice] += "Task list has been refreshed.\n"
       redirect_to :action => :index
       return
     end

    if tasklist.empty?
      flash[:error] += "No task selected? Selection cleared.\n"
      redirect_to :action => :index
      return
    end

    tasklist.each do |task_id|
      begin 
        task = DrmaaTask.find(task_id.to_i)
      rescue
        flash[:error] += "Task #{task_id} does not exist."
        next
      end
      # todo: verify that task belong to current_user here ?
      case operation
        when "postprocess"
          task.status = "postprocess"  # keyword is significant
          task.save
        when "hold"
          task.status = "On Hold"
          task.save
        when "release"
          task.status = "Queued"
          task.save
        when "suspend"
          task.status = "Suspended"
          task.save
        when "resume"
          task.status = "On CPU"
          task.save
        when "delete"
          task.destroy
        when "terminate"
          task.status = "Terminated"
          task.save
      end
      flash[:notice] += "Sent '#{operation}' operation to task #{task.id}.\n"
    end

    redirect_to :action => :index

  end

end
