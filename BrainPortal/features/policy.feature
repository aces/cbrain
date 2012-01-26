
#
# CBRAIN Project
#
# Copyright (C) 2008-2012
# The Royal Institution for the Advancement of Learning
# McGill University
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.  
#

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

