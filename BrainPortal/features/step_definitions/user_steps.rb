Given /^I am logged in$/ do
  
  user = User.create!(:full_name  => 'quire', :login => 'quire', :email => 'quire@example.com',
    :password => 'quire', :password_confirmation => 'quire', :role  => 'user')
  
  visit login_path
  fill_in "Login", :with  => user.login
  fill_in "Password", :with  => user.password
  click_button
end

