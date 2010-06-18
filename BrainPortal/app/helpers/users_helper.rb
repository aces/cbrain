#Helper methods for User views
module UsersHelper

  Revision_info="$Id$"
  
  #View helper to create a valid array for a role selection box on the
  #user create and edit pages.
  def roles_for_user(user)
    roles = [["User", "user"],["Site Manager","site_manager"]]
    
    if user.has_role? :admin
      roles << ["Admin","admin"]
    end
    
    roles
  end

end
