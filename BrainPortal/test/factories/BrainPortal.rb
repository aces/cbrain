
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
  user.site                  {|site| site.association(:site)}
end

#Group Factory
Factory.sequence :group_name do |n|
  "group_#{n}"
end

Factory.define :group do |group| 
  group.name { Factory.next :group_name }
end

Factory.define :work_group do |work_group|
  work_group.name { Factory.next :group_name }
end

#Site Factory
Factory.sequence :site_name do |n|
  "New site #{n}"
end
Factory.define :site  do |site|
  site.name { Factory.next :site_name}
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
  data_provider.type {"CbrainLocalDataProvider"}
end

#Tool Factory
Factory.sequence :tool_name do |n|
  "testing tool #{n}"
end

Factory.define :tool do |tool|
  tool.name             { Factory.next :tool_name }
  tool.drmaa_class      {"drmaa_class X"}
  tool.user             {|user| user.association(:user)}
  tool.group            {|group| group.association(:group)}
  tool.category         {"scientific tool"}
end
  


