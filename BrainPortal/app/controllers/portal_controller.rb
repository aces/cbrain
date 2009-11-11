
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
  def welcome
    unless current_user
      redirect_to login_path 
      return
    end
    
    @num_files              = current_user.userfiles.size
    @groups                 = current_user.groups.collect{|g| g.name}.join(', ')
    @default_data_provider  = current_user.user_preference.data_provider.name rescue "(Unset)"
    @default_bourreau       = current_user.user_preference.bourreau.name rescue "(Unset)"
    
    bourreau_ids = available_bourreaux(current_user).collect(&:id)
    @tasks = ActRecTask.find(:all, :conditions => {
                                       :user_id     => current_user.id,
                                       :bourreau_id => bourreau_ids
                                     } )
    @tasks_by_status = @tasks.group_by do |task|
      case task.status
      when /(On CPU|Queued|New|Data Ready)/
        :running
      when /^Failed (T|t)o/
        :failed
      when /(Completed)/
        :completed
      else
        :other
      end
    end

    @tasks_by_status = @tasks_by_status.to_hash

    @tasks_by_status[:completed] ||= []
    @tasks_by_status[:running] ||= []
    @tasks_by_status[:failed] ||= []
  end
  
  #Display general information about the CBRAIN project.
  def credits
  end
  
  #Displays more detailed info about the CBRAIN project.
  def about_us
    @revinfo = { 'Revision'            => 'unknown',
                 'Last Changed Author' => 'unknown',
                 'Last Changed Rev'    => 'unknown',
                 'Last Changed Date'   => 'unknown'
               }

    IO.popen("svn info #{RAILS_ROOT}","r") do |fh|
      fh.each do |line|
        if line.match(/^Revision|Last Changed/i)
          comps = line.split(/:\s*/,2)
          field = comps[0]
          value = comps[1]
          @revinfo[field]=value
        end
      end
    end
  end
  
end
