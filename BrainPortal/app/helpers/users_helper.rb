#Helper methods for User views
module UsersHelper

  Revision_info="$Id$"
  
  def roles_for_user(user)
    roles = [["User", "user"],["Site Manager","site_manager"]]
    
    if user.has_role? :admin
      roles << ["Admin","admin"]
    end
    
    roles
  end

end
