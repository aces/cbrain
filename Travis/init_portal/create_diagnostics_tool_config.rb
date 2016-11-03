# Creates a ToolConfig for the Diagnostics tool

# First, load all tools to make sure that diagnostics will be available
# This is extracted from the ToolConfig controller, method autoload_tools
PortalTask.descendants.map(&:name).sort.each do |tool|
      tool = Tool.new(
                  :name                    => tool.demodulize,
                  :cbrain_task_class_name  => tool,
                  :user_id                 => User.admin.id,
                  :group_id                => User.admin.own_group.id,
                  :category                => "scientific tool"
      )
      tool.save!
end
diagnostics_tool_id = Tool.where({:name => "Diagnostics"}).first.id
bourreau_id         = 2 # will always be 2 according to our installation procedure
tool_config         = ToolConfig.new({
                                       :version_name => "1.0",
                                       :description => "Diagnostics test tool",
                                       :tool_id => diagnostics_tool_id,
                                       :bourreau_id => bourreau_id,
                                       :group_id => 1,
                                       :ncpus => 1})
tool_config.save!
