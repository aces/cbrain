module GroupsHelper  #:nodoc:

  Revision_info="$Id$"
  
  #Creates a link to +url+ if group is a WorkGroup,
  #otherwise displays +text+ as static text.
  def work_group_link(group, text, url)
    if group.is_a? WorkGroup
      link_to text, url
    else
      text
    end
  end

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
