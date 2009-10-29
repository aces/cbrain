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

end
