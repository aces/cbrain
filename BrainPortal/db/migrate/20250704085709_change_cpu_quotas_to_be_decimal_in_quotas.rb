class ChangeCpuQuotasToBeDecimalInQuotas < ActiveRecord::Migration[5.0]
  def up
    change_column :quotas, :max_cpu_past_week , :decimal, precision: 24
    change_column :quotas, :max_cpu_past_month, :decimal, precision: 24
    change_column :quotas, :max_cpu_ever      , :decimal, precision: 24
  end

  def down
    change_column :quotas, :max_cpu_past_week , :integer
    change_column :quotas, :max_cpu_past_month, :integer
    change_column :quotas, :max_cpu_ever      , :integer
  end
end
