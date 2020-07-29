

class User
  include NeurohubHelpers
  def fnp
    find_nh_projects(self)
  end
  def afnp
    ensure_assignable_nh_projects(self,fnp)
  end
end

def tst_all
  u_c=User.find_by_login('u_ac_verif_creator')
  u_e=User.find_by_login('u_ac_verif_editor')
  u_m=User.find_by_login('u_ac_verif_member')
  u_n=User.find_by_login('u_ac_verif_nothin')

  [u_c, u_e, u_m, u_n].each do |u|
    [:groups, :viewable_groups, :listable_groups, :assignable_groups, :editable_groups, :fnp, :afnp].each do |m|
      groups=u.send(m)
      puts "==============="
      puts "User=#{u.name.sub("u_ac_verif_","")} Method=#{m}"
      groups.to_a.each_with_index_and_size do |g,i,t|
         name = g.name.sub("g-ac-verif-","")
         puts "  #{i+1}/#{t} -> #{name}"
      end
      print ">>> "
      return if STDIN.readline.to_s =~ /q/
    end
  end
end

tst_all

1;
