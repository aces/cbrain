class User < ActiveRecord::Base

@@id2name = nil

def self.id2name(id)
  if @@id2name
    @@id2name[id]
  else
    @@id2name = Hash.new()
    allusers = User.all.each { |u| @@id2name[u.id] = u.user_name }
    @@id2name[id]
  end
end

end
