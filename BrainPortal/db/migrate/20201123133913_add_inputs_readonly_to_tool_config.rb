class AddInputsReadonlyToToolConfig < ActiveRecord::Migration[5.0]
  def change
    add_column :tool_configs, :inputs_readonly, :boolean, default: false
  end
end
