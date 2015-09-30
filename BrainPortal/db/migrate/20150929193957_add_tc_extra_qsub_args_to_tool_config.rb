class AddTcExtraQsubArgsToToolConfig < ActiveRecord::Migration
  def change
    add_column :tool_configs, :tc_extra_qsub_args, :string
  end
end
