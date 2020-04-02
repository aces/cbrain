# There was an error in a column
class FixResourceUsageDataProviderId < ActiveRecord::Migration[5.0]
  def up
    change_column :resource_usage, :data_provider_id, :integer
  end
  def down # no advantage in going down
    true
  end
end
