Given /^I have no files$/ do
  Userfile.delete_all
end

Given /^"([^\"]*)" has (\d+) files$/ do |login, n|
  Userfile.delete_all
  user = User.find_by_login(login)
  n = n.to_i
  1.upto(n) do |i|
    single_file = SingleFile.new(:name => i.to_s, :content => i.to_s, :user_id  => user.id)
    single_file.save
  end
end

Given /^"([^\"]*)" owns the following userfiles$/ do |login, table|
  user = User.find_by_login(login)
  table.hashes.each do |hash|
    tag_ids = []
    if hash[:tags]
      hash[:tags].split(/,\s*/).each do |tag_name|
       tag = user.tags.find_by_name(tag_name)  
       unless tag
         tag = Tag.new(:name => tag_name, :user_id => user.id)
         tag.save
       end
       tag_ids << tag.id
      end
    end
    name = hash[:name]
    SingleFile.create!(:name  => name, :user_id  => user.id, :content  => name, :tag_ids => tag_ids)
  end
end

Then /^"([^\"]*)" should be on the file system$/ do |file|
  File.exists? Userfile.find_by_name(file).vaultname
end

Then /^I should see all files for collection "([^\"]*)"$/ do |collection|
  FileCollection.find_by_name(collection).list_files.each do |file|
    response.should contain(file.split('/')[-1])
  end
end
