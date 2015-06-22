class AddCostFactorToRemoteResource < ActiveRecord::Migration
  def change
    add_column :remote_resources, :cost_factor, :double
  end
end
