class RenameEnvHashInToolConfig < ActiveRecord::Migration
  def self.up
    rename_column :tool_configs, :env_hash,  :env_array
    ToolConfig.all.each do |tc|
      myenv = tc.env_array
      next if myenv.nil? || myenv.is_a?(Array)
      newenv = myenv.keys.collect { |name| [ name, myenv[name] ] }
      tc.env_array = newenv
      tc.save
    end
  end

  def self.down
    rename_column :tool_configs, :env_array, :env_hash
    ToolConfig.all.each do |tc|
      myenv = tc.env_hash
      next if myenv.nil? || myenv.is_a?(Hash)
      newenv = {}
      myenv.each do |name_val|
        name = name_val[0]
        val  = name_val[1]
        newenv[name] = val
      end
      tc.env_hash = newenv
      tc.save
    end
  end
end
