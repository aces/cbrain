class AddScriptEpilogueToToolConfig < ActiveRecord::Migration[5.0]
  def change
    add_column :tool_configs, :script_epilogue, :text, :after => :script_prologue
  end
end
