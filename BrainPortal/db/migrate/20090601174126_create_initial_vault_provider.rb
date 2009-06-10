
require 'socket'

class CreateInitialVaultProvider < ActiveRecord::Migration

  ProviderNameForVault = "OldVault"

  def self.up
    vaultdir = CBRAIN::Filevault_dir
    raise "Original Filevault_dir '#{vaultdir}' does not exist!" unless File.directory?(vaultdir)

    cachedir = CBRAIN::DataProviderCache_dir
    raise "Unfortunately the data provider cache directory '#{cachedir}' does not exist!" unless File.directory?(cachedir)

    admin = User.find_by_login("admin")
    admin_id = admin.id

    everyone = Group.find_by_name("everyone")
    everyone_id = everyone.id

    provider = VaultSmartDataProvider.new(
      :name        => ProviderNameForVault,
      :remote_user => "changethisuser",
      :remote_host => Socket.gethostname,
      :remote_port => 22,
      :remote_dir  => vaultdir,
      :user_id     => admin_id,
      :group_id    => everyone_id,
      :online      => true,
      :read_only   => false,
      :description => "This is the original CBRAIN filesystem layout"
    )
    provider.save!
  end

  def self.down
    provider = DataProvider.find_by_name(ProviderNameForVault)
    provider.destroy
  end

end
