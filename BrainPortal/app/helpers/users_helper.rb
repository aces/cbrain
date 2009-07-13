#Helper methods for User views
module UsersHelper

  Revision_info="$Id$"
  
  #Checks that the current user is the same as +user+. Used to ensure permission
  #for changing account information.
  def edit_permission?(user)
    current_user && user && (current_user == user || current_user.role == 'admin')
  end

end
