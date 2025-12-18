class AddMaxActiveTasksToCpuQuota < ActiveRecord::Migration[5.0]

  def up
    add_column :quotas, :max_active_tasks, :integer, :after => :max_cpu_ever

    unlimited_time = 1000.years.to_i # hopefully big enough

    # Migrate all limits from the old convention (in the MetaData store)
    # to the new CpuQuota attribute.

    Bourreau.all.to_a.each do |bourreau|
      bid = bourreau.id

      # Create the max entries for each user (and default for all users) for the Bourreau
      old_limit_keys = bourreau.meta.keys.map(&:to_s).grep(/\Atask_limit_user_(default|\d+)\z/)
      old_limit_keys.each do |lkey|
        limit = bourreau.meta[lkey].presence
        next unless limit # should never happen, but just in case
        uid   = (lkey == "task_limit_user_default") ? 0 : lkey.to_s.sub("task_limit_user_","").to_i
        q_req = CpuQuota.where(:remote_resource_id => bid, :user_id => uid, :group_id => 0)
        quota = q_req.first ||
                q_req.new(
                  :max_cpu_past_week  => unlimited_time,
                  :max_cpu_past_month => unlimited_time,
                  :max_cpu_ever       => unlimited_time,
                )
        quota.max_active_tasks ||= limit.to_i
        quota.save!
      end

      # Create the TOTAL max entry for the Bourreau; by convention this belongs to the core Admin user
      tot_max = bourreau.meta[:task_limit_total]
      if tot_max.present? && tot_max.to_i > 0
        q_req = CpuQuota.where(:remote_resource_id => bid, :user_id => User.admin.id, :group_id => 0)
        quota = q_req.first ||
                q_req.new(
                  :max_cpu_past_week  => unlimited_time,
                  :max_cpu_past_month => unlimited_time,
                  :max_cpu_ever       => unlimited_time,
                )
        quota.max_active_tasks ||= tot_max.to_i
        quota.save!
      end

    end
  rescue => ex
    remove_column :quotas, :max_active_tasks
    raise ex
  end

  def down
    remove_column :quotas, :max_active_tasks
  end

end
