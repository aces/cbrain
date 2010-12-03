module GroupsHelper  #:nodoc:

  Revision_info="$Id$"
  
  def change_to_project_name(name) #:nodoc:
    if name == "WorkGroup"
      "Work Project"
    elsif name == "SiteGroup"
      "Site Project"
    elsif name == "UserGroup"
      "User Project"
    elsif name == "InvisibleGroup"
      "Invisible Group"
    else
      "System Project"
    end
  end
  
end
