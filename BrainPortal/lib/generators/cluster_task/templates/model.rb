
#
# CBRAIN Project
#
# <%= "Drmaa#{class_name}" %> model as ActiveResource
#
# Original author: 
#
# $Id$
#

#A subclass of DrmaaTask to launch <%= file_name %>.
class <%= "Drmaa#{class_name}" %> < DrmaaTask

  Revision_info="$Id$"

  #########################################################################
  #This method should indicate whether or not <%= file_name %> requires 
  # arguments in order to run. If so the tasks/new view will be rendered
  # before the <%= file_name %> job is sent to the cluster.
  #
  #NOTE: The comment below is for use by rdoc.
  #########################################################################
  
  #See DrmaaTask.
  def self.has_args?
    <% if options[:no_view] %>false<% else %>true<% end %>
  end
<% unless options[:no_view] %>  
  #########################################################################
  #This method should return a hash containing the default arguments for
  # <%= file_name %>. These can be used to set up the tasks/new form.
  #The saved_args argument is the hash from the user preferences for 
  # <%= "Drmaa#{class_name}" %>. It is the has created by the 
  # self.save_options method (see below).
  #If a cb_error is sent here it will cause a redirect that defaults to the 
  # userfiles index page where the error message will be displayed.
  #
  #If you wish to redirect to another page, simply add a redirect path
  # as the second argument to cb_error. 
  #e.g:
  # cb_error "Problem in launch", {:controller => :portal, :action => :welcome}
  # cb_error "Another problem", "/userfiles"
  #
  #NOTE: The comment below is for use by rdoc.
  #########################################################################
  
  #See DrmaaTask.
  def self.get_default_args(params = {}, saved_args = nil)
    {}
  end
<% end %>
  #########################################################################
  #This method actually launches the <%= file_name %> job on the cluster, 
  # and returns the flash message to be displayed.
  #Default behaviour is to launch the job to the user's prefered cluster,
  # or if the latter is not set, to choose an available cluster at random.
  # You can select a specific cluster to launch to by setting the 
  # bourreau_id attribute on the Drmaa<%= class_name %> object (task.bourreau_id) 
  # explicitly.
  # If a cb_error is sent here, it will cause a redirect that defaults to one of 
  # the following pages:
  # 1. The argument input page for <%= name %> if the has_args? returns true.
  # 2. The userfiles index page if has_args? returns false.
  #
  # The cb_error message will be displayed to the user as 
  # a flash error after the redirect.
  #
  #If you wish to redirect to another page, simply add a redirect path
  # as the second argument to cb_error. 
  #e.g:
  # cb_error "Problem in launch", {:controller => :portal, :action => :welcome}
  # cb_error "Another problem", "/userfiles"
  #
  #NOTE: The comment below is for use by rdoc.
  #########################################################################
  
  #See DrmaaTask.
  def self.launch(params) 
    flash = "Flash[:notice] message."
    #Example (you can uncomment this and use it as a template):
    # file_ids = params[:file_ids]
    # 
    # file_ids.each do |id|
    #   userfile = Userfile.find(id, :include  => :user)
    #   task = <%= "Drmaa#{class_name}" %>.new
    #   task.user_id = userfile.user.id
    #   task.description = params[:description]
    #   task.params = { :mincfile_id => id }
    #   task.save
    #   
    #   flash += "Started <%= "Drmaa#{class_name}" %> on file '#{userfile.name}'.\n"
    # end
    flash
  end
<% unless options[:no_view] -%>
  
  #########################################################################
  #This method creates a hash of the options to be saved in the user's
  # preferences. It will be stored in:  
  # <user_preference>.other_options["<%= "Drmaa#{class_name}" %>_options"]
  # This has is automatically passed to the self.get_default_args method
  # (see above) for each <%= "Drmaa#{class_name}" %> creation request.
  #
  #NOTE: The comment below is for use by rdoc.
  #########################################################################
    
  #See DrmaaTask.
  def self.save_options(params)
    {}
  end
<% end -%>
end

