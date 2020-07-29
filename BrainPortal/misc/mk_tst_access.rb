
u_class=NormalUser
g_class=WorkGroup

a_g=Group.where("name like 'g-ac-verif-%'")
a_g.destroy_all
a_u=User.where("login like 'u_ac_verif_%'")
a_u.destroy_all

p_w='abcdABCD1234!@#$'

u_c = u_class.create!(
    :login     => 'u_ac_verif_creator',
    :full_name => 'Group Creator',
    :password  => p_w,
    :password_confirmation => p_w
)

u_e = u_class.create!(
    :login     => 'u_ac_verif_editor',
    :full_name => 'Group Editor',
    :password  => p_w,
    :password_confirmation => p_w
)

u_m = u_class.create!(
    :login     => 'u_ac_verif_member',
    :full_name => 'Group member',
    :password  => p_w,
    :password_confirmation => p_w
)

u_n = u_class.create!(
    :login     => 'u_ac_verif_nothin',
    :full_name => 'Group NOTmember',
    :password  => p_w,
    :password_confirmation => p_w
)

[false,true].each do |invisible|
  [false,true].each do |pub|
    [false,true].each do |not_assignable|
      name  = "g-ac-verif"
      name += invisible      ? "-invis"  : "-visib"
      name += pub            ? "-publc"  : "-NOpub"
      name += not_assignable ? "-NOass"  : "-assig"
      g = WorkGroup.create!(
        :name           => name,
        :creator_id     => u_c.id,
        :invisible      => invisible,
        :public         => pub,
        :not_assignable => not_assignable,
      )
      g.user_ids   = [ u_c.id, u_e.id, u_m.id ]
      g.editor_ids = [ u_c.id, u_e.id ]
    end
  end
end

1;
