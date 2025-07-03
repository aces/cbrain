class FixNegativeDiskQuotaLimits < ActiveRecord::Migration[5.0]
  def up
    # Change max_bytes from -1 to 0
    DiskQuota.where(:max_bytes => -1).update_all(:max_bytes => 0)
    # Change max_files from -1 to 0
    DiskQuota.where(:max_files => -1).update_all(:max_files => 0)
  end

  def down
    # Revert max_bytes from 0 to -1
    DiskQuota.where(:max_bytes => 0).update_all(:max_bytes => -1)
    # Revert max_files from 0 to -1
    DiskQuota.where(:max_files => 0).update_all(:max_files => -1)
  end
end
