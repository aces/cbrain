

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


dest_dp = EnCbrainSmartDataProvider.first
pid     = BrainPortal.first.id

smart_dp_ids  = [ 4 ]
browse_dp_ids = [ 2,3 ]
openneuro_dp_id = [ 19 ]

##################################################
ids = need_ids("AnyFile") { Userfile.where(:data_provider_id => smart_dp_ids + browse_dp_ids) }
run_bac( admin_bac(BackgroundActivity::CompressFile,ids) )
run_bac( admin_bac(BackgroundActivity::UncompressFile,ids) )

##################################################
run_bac( admin_bac(BackgroundActivity::CopyFile,ids).tap { |bac| bac.options = { :dest_data_provider_id => dest_dp.id } } )
newids = BackgroundActivity.last.messages.select { |m| m.to_s =~ /^\d+$/ }
run_bac( admin_bac(BackgroundActivity::DestroyFile, newids) ) if newids.present?

##################################################
smart_ids = need_ids("OnSmart") { Userfile.where(:data_provider_id => smart_dp_ids.first) }
run_bac( admin_bac(BackgroundActivity::MoveFile, smart_ids).tap { |bac| bac.options = { :dest_data_provider_id => browse_dp_ids.first } } )
run_bac( admin_bac(BackgroundActivity::MoveFile, smart_ids).tap { |bac| bac.options = { :dest_data_provider_id => smart_dp_ids.first } } )

##################################################
cids = need_ids("Cached On Portal") { Userfile.joins(:sync_status).where('sync_status.status' => "InSync").where('userfiles.data_provider_id' => smart_dp_ids + browse_dp_ids) }
run_bac( admin_bac(BackgroundActivity::CleanCache, cids) )
