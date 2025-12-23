
#
# CBRAIN Project
#
# Copyright (C) 2008-2023
# The Royal Institution for the Advancement of Learning
# McGill University
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

namespace :cbrain do
  namespace :integrators do
    desc "Switch tools from the old Boutiques integrator to the new integrator"

    task :migrate, [:action, :tool_id] => :environment do |t,args|

      args.with_defaults(:action => 'check', :tool_id => nil)
      action     = args.action
      argtool_id = args.tool_id # could be nil

      tool=nil
      if argtool_id.present?
        if ! argtool_id.match?(/\A\d+\z/) || ! (argtool=Tool.where(:id => argtool_id).first)
          raise "Cannot find a tool with ID=#{argtool_id}"
        end
      end

      # Usage
      if action !~ /\A(list|check|upgrade)\z/
        puts <<-USAGE
        Usage:
          rake cbrain:integrators:migrate[list]          # default
          rake cbrain:integrators:migrate[list,tool_id]
          rake cbrain:integrators:migrate[check]
          rake cbrain:integrators:migrate[check,tool_id]
          rake cbrain:integrators:migrate[upgrade]       # does all
          rake cbrain:integrators:migrate[upgrade,tool_id]

        (The square bracketed keywords after "migrate" are
        literal on the command line)

        This rake task will check or upgrade one or several
        tools that are cuurently integrated with the old
        Boutiques integrator. The 'check' action will just
        print the state of the tools. The 'upgrade' will actually
        perform the migration to the new integrator.

        If given a tool ID in argument, the operation of checking
        or upgrading will only be performed on that particular tool.

        It is highly recommended to run this on a single portal WHILE
        THE SERVICE IS OFFLINE, then commit and push the changes to the
        plugins that were updated (the descriptors will be copied from
        cbrain_task_descriptors/ to boutiques_descriptors/ ).
        USAGE
        exit 1
      end

      old_tools = Tool
        .where('cbrain_task_class_name like "CbrainTask::%"')
        .to_a
        .select { |t| t.cbrain_task_class.respond_to?(:generated_from) }

      if old_tools.empty?
        puts "There are no tools configured with the old integrator in this system."
        exit 1
      end

      if argtool
        if ! old_tools.any? { |t| t.id == argtool.id }
          puts "Error: the tool ID #{argtool_id} doesn't match any tool configured with the old integrator."
          exit 1
        end
        old_tools = [ argtool ]
      end

      old_tools.sort! { |t1,t2| t1.id <=> t2.id }
      infos = old_tools.map do |tool|
        klass    = tool.cbrain_task_class
        descpath = klass.generated_from.descriptor_path # in installed-plugins
        srcpath  = Pathname.new(File.realpath(descpath)) # resolving symlink too
        srcdir,jsonbase = srcpath.split   # ".../pluginname/cbrain_task_descriptors", "desc.json"
        problems=[];warnings=[]
        if srcdir.basename.to_s == "cbrain_task_descriptors"
          pluginname = srcdir.dirname.basename.to_s # "pluginname"
        else
          pluginname = "Unknown!"
          problems << 'PlugName'
        end
        task_count = klass.count.to_s
        wd_task_count = klass.wd_present.count
        task_count += "/wd=#{wd_task_count}" if wd_task_count > 0
        btq=BoutiquesSupport::BoutiquesDescriptor.new_from_file(srcpath.to_s)
        warnings << "ToolName!=#{btq.name}" if btq.name != tool.name
        btqrubyname = btq.name_as_ruby_class
        oldrubyname = klass.name.demodulize
        problems << "Ruby(#{oldrubyname},#{btqrubyname})" if btqrubyname != oldrubyname
        if BoutiquesTask.const_defined?(btqrubyname.to_sym)
          problems << "Const(#{oldrubyname})"
        end
        warns = warnings.join('+')
        probs = problems.join('+')
        [ tool.id, tool.name, pluginname, jsonbase, task_count, warns, probs ]
      end

      if action == 'list'
        require "hirb.rb"
        extend Hirb::Console
        prettyinfos = infos.dup
        prettyinfos.unshift(["Tool ID", "Name", "Plugin", "Descriptor", "Tasks", "Warns", "Probs"])
        table prettyinfos, :headers => false, :resize => false
        exit 0
      end

      if action == 'upgrade' && infos.any? { |row| row.last != '' }
        puts "Error: there are tools whose integrations are problematic. Use the 'list' action."
        exit 2
      end

      if action == 'check'
        puts_magenta "In 'check' mode, none of the actions below are actually performed."
        puts_magenta "We just pretend to do it all the way before actually making any changes."
      end

      # MIGRATE
      old_tools.each do |tool|
        klass    = tool.cbrain_task_class
        descpath = klass.generated_from.descriptor_path # in installed-plugins
        srcpath  = Pathname.new(File.realpath(descpath)) # resolving symlink too
        srcdir,jsonbase = srcpath.split   # ".../pluginname/cbrain_task_descriptors", "desc.json"
        pluginbase = srcdir.dirname       # ".../pluginname"
        btq      = BoutiquesSupport::BoutiquesDescriptor.new_from_file(srcpath.to_s)
        inputids = btq.inputs.map(&:id)
        #puts_red "I=#{inputids.inspect}"
        tasks    = klass.all.to_a

        puts_cyan "\nAdjusting: TOOL=#{tool.name} CLASS=#{klass.name} TASKS=#{tasks.size}"

        # JSON Path adjustment
        btq_dir = "#{pluginbase}/boutiques_descriptors"
        Dir.mkdir(btq_dir,0700) if ! File.directory?(btq_dir)
        cp_com = [ "cp","-p","#{srcpath}", "#{btq_dir}/#{jsonbase}" ]
        cp_com.unshift("echo") if action == 'check'
        puts_red "Warning: there is already a BTQ descriptor in #{btq_dir}/#{jsonbase}" if File.file?("#{btq_dir}/#{jsonbase}")
        if ! system(*cp_com)
          puts_red "Could not copy '#{srcpath}' to '#{btq_dir}/#{jsonbase}' ???"
          exit 2
        end

        # TASKS object adjustment
        tasks.each_with_index do |task,idx|
          puts " -> Adjusting task #{task.id} (#{idx+1}/#{tasks.size})" if sprintf("%6.6d",idx) =~ /00$/
          puts_yellow "BEFORE: #{task.params.inspect}" if action == 'check'
          top = task.params
          top["invoke"] ||= {}
          inv = top["invoke"]
          inputids.each do |inputid|
            if top.has_key?(inputid) && ! inv.has_key?(inputid)
              inv[inputid] = top.delete(inputid)
            end
          end
          task.params = top
          puts_yellow "AFTER: #{task.params.inspect}" if action == 'check'
          task.update_column(:params, top)            if action == 'upgrade'
        end # adjust all tasks
        puts " -> Finished adjusting all tasks"

        # TOOL object adjustment
        btqrubyname = btq.name_as_ruby_class
        tool.cbrain_task_class_name = "BoutiquesTask::#{btqrubyname}"
        puts " -> Adjusting TOOL class to #{tool.cbrain_task_class_name}"
        tool.descriptor_name = btq.name
        tool.save! if action == 'upgrade'
        tool.addlog("Migrated to new Boutiques integrator")
      end # each oldtoold

      puts "All migrations finished."

    end # task      cbrain:integrators:migrate
  end   # namespace cbrain:integrators
end     # namespace cbrain

