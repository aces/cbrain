
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

Given /^I am logged in as "([^\"]*)" with password "([^\"]*)"$/ do |login, password|  
  visit login_path
  fill_in "Login", :with  => login
  fill_in "Password", :with  => password
  click_button
end

Given /^I am logged in as "([^\"]*)" with password "([^\"]*)" and I accepted the policy$/ do |login, password|
   When %{I am logged in as "#{login}" with password "#{password}"}
   @user.policy = true
   
end

Given /^the following user records$/ do |table|
  User.all.each do |u|
    if u.login != "admin"
      u.destroy
    end
  end
  
  table.hashes.each do |hash|
    name = hash[:login]
    password = hash[:password]
    role = hash[:role]
    
    User.create!(:full_name  => name, :login => name, :email => "#{name}@example.com",
      :password => password, :password_confirmation => password, :role  => role)

  end
end

