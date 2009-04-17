Given /^I have no files$/ do
  Userfile.delete_all
end

Then /^"([^\"]*)" should be on the file system$/ do |file|
  File.exists? Userfile.find_by_name(file).vaultname
end

Then /^I should see all files for collection "([^\"]*)"$/ do |collection|
  FileCollection.find_by_name(collection).list_files.each do |file|
    response.should contain(file.split('/')[-1])
  end
end
