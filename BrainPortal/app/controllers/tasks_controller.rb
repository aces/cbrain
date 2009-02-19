
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
    @tasks = []
    CBRAIN_CLUSTERS::CBRAIN_cluster_list.each do |cluster_name|
      DrmaaTask.adjust_site(cluster_name)
      begin
        if current_user.role == 'admin'
          tasks = DrmaaTask.find(:all) || []
        else
          tasks = DrmaaTask.find(:all, :params => { :user_id => current_user.id } ) || []
        end
        tasks = [ tasks ] unless tasks.is_a?(Array)
        @tasks.concat(tasks)
      rescue => e
        flash.now[:error] ||= ""
        flash.now[:error] += "Cluster '#{cluster_name}' is down: #{e.to_s}"
      end
    end
    @tasks
  end

  # GET /tasks/Montague/1
  # GET /tasks/Montague/1.xml
  def show
    cluster_name = params[:cluster_name]
    DrmaaTask.adjust_site(cluster_name)
    @task = DrmaaTask.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @task }
    end

  rescue
    access_error(404)

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

    tasklist.each do |task_cl_id|

      (cluster_name,task_id) = task_cl_id.split(/,/)
      begin 
        DrmaaTask.adjust_site(cluster_name)
        task = DrmaaTask.find(task_id.to_i)
      rescue
        flash[:error] += "Task #{task_id} does not exist."
        next
      end

      continue if task.user_id != current_user.id && current_user.role != 'admin'

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
