module GroupsHelper  #:nodoc:

  Revision_info="$Id$"
  
  def change_to_project_name(name)
    if name == "WorkGroup"
      "Work Project"
    elsif name == "SiteGroup"
      "Site Project"
    elsif name == "UserGroup"
      "User Project"
    else
      "System Project"
    end
  end
  
end
