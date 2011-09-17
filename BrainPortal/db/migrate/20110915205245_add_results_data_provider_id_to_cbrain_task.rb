class AddResultsDataProviderIdToCbrainTask < ActiveRecord::Migration
  def self.up
    add_column    :cbrain_tasks, :results_data_provider_id, :integer
  end

  def self.down
    remove_column :cbrain_tasks, :results_data_provider_id
  end
end
