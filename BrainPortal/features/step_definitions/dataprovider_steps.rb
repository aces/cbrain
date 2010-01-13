Given /^"([^\"]*)" has a data provider called "([^\"]*)"$/ do |login, name|
  Factory.create(:data_provider, :name => name, :user => User.find_by_login(login))
end
