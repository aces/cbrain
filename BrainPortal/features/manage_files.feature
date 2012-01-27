
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

Feature: Manage Files

   In order to manage files
   As a user
   I want to upload, tag and delete files.
   
   Background:
   Given the following user records
   | login | password | role    |
   | manag   | secret   | manager |
   | tarek    | secret   | user    |

   
   Scenario: Upload a file
   Given I am logged in as "tarek" with password "secret"
   And I am on the userfiles page
   And I have no files
   When I attach the file at "test/fixtures/files/test__xxx__yyy__1234321.txt" to "upload_file"
   And I press "Upload file"
   Then I should see "test__xxx__yyy__1234321.txt"
   And "test__xxx__yyy__1234321.txt" should be on the file system
   
   Scenario: Create a collection
   Given I am logged in as "tarek" with password "secret"
   And I am on the userfiles page
   And I have no files
   When I attach the file at "test/fixtures/files/tarek.tar.gz" to "upload_file"
   And I select "Create collection" from "archive"
   And I press "Upload file"
   Then I should see "tarek"
   And I should see "(Collection)"
   When I follow "tarek"
   Then I should see all files for collection "tarek"
   
   Scenario Outline: Show or hide admin options
   Given I am logged in as "<login>" with password "secret"
   And I am on the userfiles page
   Then I should <action>
   
   Examples:
    | login | action                                 |
    | admin1 | see "Show all files on the system"     |
    | manag1 | not see "Show all files on the system" |
    | tarek | not see "Show all files on the system" |

    Scenario: Pagination for more than 50 files
    Given I am logged in as "tarek" with password "secret"
    And "tarek" has a data provider called "tarek_test_provider"
	And "tarek" has 75 files from "tarek_test_provider"
    And I am on the userfiles page
    Then I should see "« Previous"
    And I should see "Next »"
    And I should see "Toggle Pagination"
    When I follow "Toggle Pagination"
    Then I should not see "« Previous"
    And I should not see "Next »"
    But I should see "Toggle Pagination"
    
    Scenario: Pagination for less than 50 files
    Given I am logged in as "tarek" with password "secret"
    And "tarek" has 25 files
    And I am on the userfiles page
    Then I should not see "« Previous"
    And I should not see "Next »"
    And I should not see "Toggle Pagination"
    
    Scenario: Filter file types
    Given "tarek" owns the following userfiles
    | name                 |
    | my_jiv_a.header      |
    | my_jiv_b.header      |
    | my_jiv_a.raw_byte    |
    | my_jiv_b.raw_byte.gz |
    | my_minc_a.mnc        |
    | my_minc_b.mnc        |
    And I am logged in as "tarek" with password "secret"
    And I am on the userfiles page
    When I follow "MINC Files"
    Then I should be on the userfiles page
    And I should see "my_minc_a.mnc"
    And I should see "my_minc_b.mnc"
    But I should not see "my_jiv_a.raw_byte"
    And I should not see "my_jiv_b.raw_byte.gz"
    And I should not see "my_jiv_a.header"
    And I should not see "my_jiv_b.header"
    When I follow "All Files"
    Then I should be on the userfiles page
    And I should see "my_minc_a.mnc"
    And I should see "my_minc_b.mnc"
    And I should see "my_jiv_a.raw_byte"
    And I should see "my_jiv_b.raw_byte.gz"
    And I should see "my_jiv_a.header"
    And I should see "my_jiv_b.header"
    When I follow "Jiv Files"
    Then I should be on the userfiles page
    And I should not see "my_minc_a.mnc"
    And I should not see "my_minc_b.mnc"
    But I should see "my_jiv_a.raw_byte"
    And I should see "my_jiv_b.raw_byte.gz"
    And I should see "my_jiv_a.header"
    And I should see "my_jiv_b.header"
    
    @new
    Scenario: Filter tags
    Given "tarek" owns the following userfiles
    | name  | tags       |
    | file1 | tag1       |
    | file2 | tag1       |
    | file3 | tag2       |
    | file4 | tag1, tag2 |
    And I am logged in as "tarek" with password "secret"
    And I am on the userfiles page
    Then I should see "file1"
    And I should see "file2"
    And I should see "file3"
    And I should see "file4"
    And I should see "tag1"
    And I should see "tag2"
    When I follow "tag1"
    Then I should see "file1"
    And I should see "file2"
    And I should see "file4"
    But I should not see "file3"
    When I follow "tag2"
    Then I should see "file4"
    But I should not see "file1"
    And I should not see "file2"
    And I should not see "file3"
    When I follow "All Files"
    Then I should see "file1"
    And I should see "file2"
    And I should see "file3"
    And I should see "file4"
    When I follow "tag2"
    Then I should see "file3"
    And I should see "file4"
    But I should not see "file1"
    And I should not see "file2"

