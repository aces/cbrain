Feature: Manage Files

   In order to manage files
   As a user
   I want to upload, tag and delete files.
   
   Scenario: Upload a file
   Given I am logged in
   And I am on userfiles page
   And I have no files
   When I attach the file at "test/fixtures/files/test__xxx__yyy__1234321.txt" to "upload_file"
   And I press "Upload file"
   Then I should see "test__xxx__yyy__1234321.txt"
   And "test__xxx__yyy__1234321.txt" should be on the file system
   
   Scenario: Create a collection
   Given I am logged in
   And I am on userfiles page
   And I have no files
   When I attach the file at "test/fixtures/files/tarek.tar.gz" to "upload_file"
   And I select "Create collection" from "archive"
   And I press "Upload file"
   Then I should see "tarek"
   And I should see "(Collection)"
   When I follow "tarek"
   Then I should see all files for collection "tarek"
   