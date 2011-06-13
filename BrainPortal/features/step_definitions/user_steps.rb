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


