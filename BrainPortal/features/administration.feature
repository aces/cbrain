Feature Administration

   In order administer the system
   As an administrator
   I want to create, delete, update users, groups and institutions and assign them to each other.
   
   Background:
   Given the following user records
   | login | password | role  |
   | admin | secret   | admin |
   
   
   Scenario: Create user, group, institution and link them to each other
   Given I am logged in as "admin" with password "secret"
   And I am on the institutions page
   When I press "Create New Institution"
   Then I should be on create institution page
   When I fill in "Name" with "__NewInstitution__"
   And I fill in "City" with "__NewCity__"
   And I press "Create"
   Then I should be on the institutions page
   And I should see "__NewInstitution__"
   And I should see "__NewCity__"
   When I follow "Users"
   Then I should be on the users page
   When I press "Create New User"
   Then I should be on the new user page
   When I fill in "user_full_name" with "___NEW_USER___"
   And I fill in "user_login" with "___NEW_USER___"
   And I fill in "user_email" with "___NEW_USER___@HERE"
   And I select "manager" from "user_role"
   And I fill in "user_password" with "secret"
   And I fill in "user_password_confirmation" with "secret"
   And I press "Create User"
   Then I should be on the users page
   And I should see "___NEW_USER___"
   And I should see "manager"
   When I follow "Groups"
   Then I should be on the groups page
   When I press "Create New Group"
   Then I should be on the new group page
   When I fill in "Name" with "__NEW_GROUP__"
   And I select "___NEW_USER___" from "Manager"
   And I select "__NewInstitution__" from "Institution"
   And I press "Create"
   Then I should be on the groups page
   And I should see "Group was successfully created."
   When I follow "Logout"
   Then I should be on the login page
   And I should see "You have been logged out."
   When I fill in "login" with "___NEW_USER___"
   And I fill in "password" with "secret"
   And I press "Log in"
   Then I should be on the homepage
   And I should see "Logged in successfully"
   
   
   
   
   
   
   
   
   
   