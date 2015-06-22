class DropCreateVmFactories1 < ActiveRecord::Migration
  def up
    drop_table :create_vm_factories
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
