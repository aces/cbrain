
#
# CBRAIN Project
#
# Contoller for the entrypoint to cbrain
#
# Original author: Tarek Sherif
#
# $Id$
#

#Controller for the entry point into the system.
class PortalController < ApplicationController

  Revision_info="$Id$"
  
  #Display a user's home page with information about their account.
  def welcome #:nodoc:
    unless current_user
      redirect_to login_path 
      return
    end
    
    @num_files              = current_user.userfiles.size
    @groups                 = current_user.groups.collect{|g| g.name}.join(', ')
    @default_data_provider  = current_user.user_preference.data_provider.name rescue "(Unset)"
    @default_bourreau       = current_user.user_preference.bourreau.name rescue "(Unset)"
        
    if current_user.has_role? :admin
      @active_users = Session.active_users
      if request.post?
        if params[:lock_portal] == "lock"
          BrainPortal.current_resource.lock!
          flash.now[:notice] = "This portal has been locked."
        elsif params[:lock_portal] == "unlock"
          BrainPortal.current_resource.unlock!
          flash.now[:notice] = "This portal has been unlocked."
          flash.now[:error] = ""        
        end
      end
    elsif current_user.has_role? :site_manager
      @active_users = Session.active_users(:conditions  => {:site_id  => current_user.site_id})
    end
    
    bourreau_ids = Bourreaux.find_all_accessible_by_user(current_user, :conditions => { :online => true } ).collect(&:id)
    @tasks = CbrainTask.find(:all, :conditions => {
                                       :user_id     => current_user.id,
                                       :bourreau_id => bourreau_ids
                                     } )
    @tasks_by_status = @tasks.group_by do |task|
      case task.status
      when /((#{CbrainTask::COMPLETED_STATUS.join('|')}))/o
        :completed
      when /(#{CbrainTask::RUNNING_STATUS.join('|')})/o
        :running
      when /(#{CbrainTask::FAILED_STATUS.join('|')})/o
        :failed
      else
        :other
      end
    end

    @tasks_by_status = @tasks_by_status.to_hash

    @tasks_by_status[:completed] ||= []
    @tasks_by_status[:running]   ||= []
    @tasks_by_status[:failed]    ||= []
  end
  
  #Display general information about the CBRAIN project.
  def credits #:nodoc:
    # Nothing to do, just let the view show itself.
  end
  
  #Displays more detailed info about the CBRAIN project.
  def about_us #:nodoc:
    myself = RemoteResource.current_resource
    info   = myself.info

    @revinfo = { 'Revision'            => info.revision,
                 'Last Changed Author' => info.lc_author,
                 'Last Changed Rev'    => info.lc_rev,
                 'Last Changed Date'   => info.lc_date
               }

  end
  
end
