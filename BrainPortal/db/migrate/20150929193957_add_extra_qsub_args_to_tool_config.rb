class AddExtraQsubArgsToToolConfig < ActiveRecord::Migration
  def change
    add_column :tool_configs, :extra_qsub_args, :string
  end
end
