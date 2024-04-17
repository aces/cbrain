

def need_ids(desc)
  ids = yield.pluck(:id)
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

def admin_bac(klass,items,rrid)
  klass.new(
    :user_id            => 1,
    :remote_resource_id => rrid,
    :items              => items,
    :status             => 'InProgress',
  )
end


dest_dp = EnCbrainSmartDataProvider.first
pid     = BrainPortal.first.id
bid     = Bourreau.first.id

##################################################
ids = need_ids("TasksWithWorkdirs") { CbrainTask.wd_present }
run_bac( admin_bac(BackgroundActivity::ArchiveTaskWorkdir,ids,bid) )
run_bac( admin_bac(BackgroundActivity::UnarchiveTaskWorkdir,ids,bid) )
run_bac( admin_bac(BackgroundActivity::ArchiveTaskWorkdir,ids,bid).tap { |bac| bac.options = { :archive_data_provider_id => dest_dp.id } } )
run_bac( admin_bac(BackgroundActivity::UnarchiveTaskWorkdir,ids,bid) )

##################################################
ids = need_ids("TaskToTerminate") { CbrainTask.status('Completed').wd_present }
run_bac( admin_bac(BackgroundActivity::TerminateTask, ids, bid) )
run_bac( admin_bac(BackgroundActivity::RemoveTaskWorkdir, ids, bid) )
run_bac( admin_bac(BackgroundActivity::DestroyTask, ids, bid) )
