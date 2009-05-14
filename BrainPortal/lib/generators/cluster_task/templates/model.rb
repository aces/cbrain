
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
  #########################################################################
  def self.get_default_args(params = {})
    {}
  end
<% end %>
  #########################################################################
  #This method actually launches the <%= file_name %> job on the cluster, 
  # and returns the flash message to be displayed.
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
end

