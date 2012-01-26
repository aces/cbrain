
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

Given /^I have no files$/ do
  Userfile.delete_all
end

Given /^"([^\"]*)" has (\d+) files from "([^\"]*)"$/ do |login, n, data_provider|
  Userfile.delete_all
  user = User.find_by_login(login)
  n = n.to_i
  1.upto(n) do |i|
    single_file = SingleFile.new(:name => i.to_s, :user_id  => user.id)
    single_file.data_provider = DataProvider.find_by_name(data_provider)
    single_file.cache_writehandle { |io| io.write(i.to_s) }
    single_file.save
  end
end

Given /^"([^\"]*)" owns the following userfiles$/ do |login, table|
  user = User.find_by_login(login)
  table.hashes.each do |hash|
    tag_ids = []
    if hash[:tags]
      hash[:tags].split(/,\s*/).each do |tag_name|
       tag = user.available_tags.find_by_name(tag_name)  
       unless tag
         tag = Tag.new(:name => tag_name, :user_id => user.id)
         tag.save
       end
       tag_ids << tag.id
      end
    end
    name = hash[:name]
    s = SingleFile.create!(:name  => name, :user_id  => user.id, :tag_ids => tag_ids)
    s.cache_writehandle { |io| io.write(name) }
  end
end

Then /^"([^\"]*)" should be on the file system$/ do |file|
  File.exists? Userfile.find_by_name(file).cache_full_path
end

Then /^I should see all files for collection "([^\"]*)"$/ do |collection|
  FileCollection.find_by_name(collection).list_files.map(&:name).each do |file|
    response.should contain(file.split('/')[-1])
  end
end


When /^I attach the file at "([^\"]*)" to "([^\"]*)"$/ do |arg1, arg2|
  pending # express the regexp above with the code you wish you had
end

Given /^"([^\"]*)" has "([^\"]*)" files$/ do |login, amount|
  amount.to_i.each do 
    Factory.create(:userfile, :user => User.find_by_login(login))
  end
end

