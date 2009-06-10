class AssignAllFilesToVaultProvider < ActiveRecord::Migration
  # NOTE data provider name OldVault must be same as migration that
  # creates the data provider itself (see earlier migrations)
  def self.up
    provider = DataProvider.find_by_name("OldVault")
    provider_id = provider.id

    allfiles = Userfile.all
    allfiles.each do |u|
      next unless u.data_provider_id.blank?
      u.data_provider_id = provider_id
      u.save!
    end
  end

  def self.down
    provider = DataProvider.find_by_name("OldVault")
    provider_id = provider.id

    allfiles = Userfile.all
    allfiles.each do |u|
      next if u.data_provider_id.blank? || u.data_provider_id != provider_id
      u.data_provider_id = nil
      u.save!
    end
  end
end
