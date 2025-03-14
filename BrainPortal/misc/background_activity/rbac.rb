

def need_ids(desc)
  ids = yield.pluck('userfiles.id')
  raise "Oh no no IDS found for #{desc}" if ids.blank?
  ids = ids.shuffle[0..1]
  puts "#{desc}: #{ids.join(", ")}"
  ids
end

def run_bac(bac)
  puts "Running #{bac.class}"
  bac.save!
  while bac.reload.status == 'InProgress'
    sleep 1
  end
  puts "Final: #{bac.status}"
  puts "Messages: #{bac.messages.join(", ")}"
end

def admin_bac(klass,items)
  klass.new(
    :user_id            => 1,
    :remote_resource_id => BrainPortal.first.id,
    :items              => items,
    :status             => 'InProgress',
  )
end


dest_dp_id   = EnCbrainSmartDataProvider.first.id
browse_dp_id = 3
gid = User.admin.own_group.id
colnames  = %w( Col1 Col2 Col3 )
filenames = %w( f1.png f2.png f3.png )


##################################################
regall = colnames.map { |x| "FileCollection-#{x}" } + filenames.map { |x| "ImageFile-#{x}" }
run_bac( admin_bac(BackgroundActivity::RegisterFile,regall).tap { |bac| bac.options = { :src_data_provider_id => browse_dp_id, :group_id => gid } } )
newids = BackgroundActivity.last.messages.select { |x| x.to_s =~ /^\d+$/ }
run_bac( admin_bac(BackgroundActivity::UnregisterFile,newids) )

##################################################
run_bac( admin_bac(BackgroundActivity::RegisterAndCopyFile,regall).tap { |bac| bac.options = { :src_data_provider_id => browse_dp_id, :group_id => gid, :dest_data_provider_id => dest_dp_id } } )
newids = BackgroundActivity.last.messages.select { |x| x.to_s =~ /^\d+$/ }
run_bac( admin_bac(BackgroundActivity::DestroyFile,newids) )
dp_ids = Userfile.where(:name => colnames + filenames, :data_provider_id => browse_dp_id).pluck(:id)
run_bac( admin_bac(BackgroundActivity::UnregisterFile, dp_ids) ) if dp_ids.present?

##################################################
run_bac( admin_bac(BackgroundActivity::RegisterAndMoveFile,regall).tap { |bac| bac.options = { :src_data_provider_id => browse_dp_id, :group_id => gid, :dest_data_provider_id => dest_dp_id } } )
newids = BackgroundActivity.last.messages.select { |x| x.to_s =~ /^\d+$/ }
run_bac( admin_bac(BackgroundActivity::MoveFile,newids).tap { |bac| bac.options = { :dest_data_provider_id => browse_dp_id } } )
run_bac( admin_bac(BackgroundActivity::UnregisterFile,newids) )
