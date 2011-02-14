class AddNcpusToToolConfig < ActiveRecord::Migration
  def self.up
    add_column    :tool_configs, :ncpus, :integer
  end

  def self.down
    remove_column :tool_configs, :ncpus
  end
end
