
#
# CBRAIN Project
#
# <%= "Drmaa#{class_name}" %> model as ActiveResource
#
# Original author: 
#
# $Id$
#

class <%= "Drmaa#{class_name}" %> < DrmaaTask

  Revision_info="$Id$"

  #########################################################################
  #This method should indicate whether or not <%= file_name %> requires 
  # arguments in order to run. If so the tasks/new view will be rendered
  # before the <%= file_name %> job is sent to the cluster.
  #########################################################################
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
  #If an exception is raised here it will cause a redirect to the 
  # userfiles index page where the exception message will be displayed.
  #########################################################################
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
  # cluster_name attribute on the Drmaa<%= class_name %> object (task.cluster_name) 
  # explicitly.
  #If an exception is raised here it will cause a redirect to the 
  # tasks/new page for <%= name %> where the exception message will be 
  # displayed.
  #########################################################################
  def self.launch(params)
    flash = "Flash[:notice] message."
    #Example (you can uncomment this and use it as a template):
    # file_ids = params[:file_ids]
    # 
    # file_ids.each do |id|
    #   userfile = Userfile.find(id, :include  => :user)
    #   task = <%= "Drmaa#{class_name}" %>.new
    #   task.user_id = userfile.user.id
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
  #########################################################################
  def self.save_options(params)
    {}
  end
<% end -%>
end

