class AddVersionNameToToolConfig < ActiveRecord::Migration
  def self.up
    add_column    :tool_configs, :version_name, :string, :after => :id
    ToolConfig.all.each do |tc|
      begin
        if tc.applies_to_bourreau_and_tool?
          tc.version_name = $1 if tc.short_description =~ /(\d+\.[\d\.]+)/
          tc.save!
        end
      rescue ActiveRecord::RecordInvalid
        if tc.version_name.blank?
          tc.version_name = "TC_#{tc.id}"
        else
          tc.version_name = tc.version_name + "_TC_#{tc.id}"
        end
        tc.save!
      end
    end
  end

  def self.down
    remove_column :tool_configs, :version_name
  end
end
