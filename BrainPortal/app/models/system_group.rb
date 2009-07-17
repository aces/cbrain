
#
# CBRAIN Project
#
# Group model
#
# Original author: Tarek Sherif
#
# $Id$
#

#This model represents an group created automatically by the system (as opposed to WorkGroup). 
#Currently, these groups include: 
#[*everyone*] 
#   The group representing all users on the system.
#[<b>single user groups</b>] 
#   These groups are meant to represent a single individual user. 
#   They are created when a user is created and use the user's login as their name.
#
#These groups are *not* meant to be modified.
class SystemGroup < Group

  Revision_info="$Id$"
  
end
