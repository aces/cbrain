
#User factory
Factory.sequence :email do |n|
  "user#{n}@example.com"
end

Factory.sequence :login do |n|
  "user#{n}"
end

Factory.define :user do |user|
  user.full_name             { "Bob Brainiac"}
  user.login                 { Factory.next :login }
  user.email                 { Factory.next :email }
  user.password              { "password" }
  user.password_confirmation { "password" }
  user.role                  { "user" }
end

#Group Factory
Factory.sequence :group_name do |n|
  "group_#{n}"
end

Factory.define :group do |group| 
  group.name { Factory.next :group_name }
end


#Data Provider Factory
Factory.sequence :data_provider_name do |n|
  "test_dataprovider#{n}"
end

Factory.define :data_provider do |data_provider|
  data_provider.name {Factory.next :data_provider_name}
  data_provider.user {|user| user.association(:user)}
  data_provider.group {|group| group.association(:group)}
  data_provider.read_only true
end

