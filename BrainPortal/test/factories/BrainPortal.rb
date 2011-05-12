
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

class DataProvider 
  def mkdir_cache_providerdir
    true
  end
end

Factory.define :data_provider do |data_provider|
  data_provider.name {Factory.next :data_provider_name}
  data_provider.user {|user| user.association(:user)}
  data_provider.group {|group| group.association(:group)}
  data_provider.read_only true
  data_provider.class {"CbrainLocalDataProvider"}
end

#Tool Factory
Factory.sequence :tool_name do |n|
  "testing tool #{n}"
end

Factory.define :tool do |tool|
  tool.name             { Factory.next :tool_name }
  tool.user             {|user| user.association(:user)}
  tool.group            {|group| group.association(:group)}
  tool.category         {"scientific tool"}
end
  
#Userfile factory
Factory.sequence :userfile_name do |n|
  "File_#{n}"
end

Factory.define :userfile do |userfile|
    userfile.name           {Factory.next :userfile_name}
    userfile.user           {|user| user.association(:user)}
    userfile.group          {|group| group.association(:group)}
    userfile.data_provider  {|data_provider| data_provider.association(:data_provider)}
end

#Tag factory
Factory.sequence :tag_name do |n|
  "tag #{n}"
end

Factory.define :tag do |tag|
  tag.name {Factory.next :tag_name}
  tag.user {|user| user.association(:user)}
  tag.group {|group| group.association(:group)}
end


#Remote resource factory
Factory.sequence :rr_name do |n|
  "rr#{n}"
end

Factory.define :remote_resource do |remote_resource|
  remote_resource.name   {Factory.next :rr_name}
  remote_resource.user   {|user| user.association(:user)}
  remote_resource.group  {Group.find_by_name('everyone')}
  remote_resource.online { true }
end
