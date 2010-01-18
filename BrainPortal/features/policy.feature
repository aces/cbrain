Feature:
	In order to use cbrain
	A user
	Should accept the user policy
	

	
	Scenario: A user logged in before accepting the policy
		Given I am logged in as "tarek" with password "secret"
   		When I go to the welcome page
		Then I should see "User Agreement"
		When I press "accept"
		Then I should see "Welcome to CBRAIN"
		
	Scenario: A user logs in and had already accepted the policy
		Given I am logged in as "tarek" with password "secret" and I accepted the policy
		When I go to the welcome page
		Then I should see "Welcome to CBRAIN"
	
	Scenario: A user logs in and does not accept the agreement
		Given I am logged in as "tarek" with password "secret"
		When I go to the welcome page
		Then I should see "User Agreement"
		When I press "Reject"
		Then I should see "Sorry"

	