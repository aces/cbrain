
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

    #############################################################
    # MIGRATE
    #############################################################
    desc "Switch tools from the old Boutiques integrator to the new integrator"
    task :migrate, [:action, :tool_id] => :environment do |t,args|

      args.with_defaults(:action => 'list', :tool_id => nil)
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
        oldklassname = tool.cbrain_task_class_name
        oldklass = tool.cbrain_task_class
        descpath = oldklass.generated_from.descriptor_path # in installed-plugins
        srcpath  = Pathname.new(File.realpath(descpath)) # resolving symlink too
        srcdir,jsonbase = srcpath.split   # ".../pluginname/cbrain_task_descriptors", "desc.json"
        problems=[];warnings=[]
        if srcdir.basename.to_s == "cbrain_task_descriptors"
          pluginname = srcdir.dirname.basename.to_s # "pluginname"
        else
          pluginname = "Unknown!"
          problems << 'PlugName'
        end
        task_count = oldklass.count.to_s
        wd_task_count = oldklass.wd_present.count
        task_count += "/wd=#{wd_task_count}" if wd_task_count > 0
        btq=BoutiquesSupport::BoutiquesDescriptor.new_from_file(srcpath.to_s)
        warnings << "ToolName!=#{btq.name}" if btq.name != tool.name
        btqrubyname = btq.name_as_ruby_class
        oldrubyname = oldklassname.demodulize
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
        oldklassname = tool.cbrain_task_class_name
        oldklass     = tool.cbrain_task_class
        descpath     = oldklass.generated_from.descriptor_path # in installed-plugins
        srcpath      = Pathname.new(File.realpath(descpath)) # resolving symlink too
        srcdir,jsonbase = srcpath.split   # ".../pluginname/cbrain_task_descriptors", "desc.json"
        pluginbase   = srcdir.dirname       # ".../pluginname"
        pluginname   = pluginbase.basename.to_s  # "pluginname"
        btq          = BoutiquesSupport::BoutiquesDescriptor.new_from_file(srcpath.to_s)

        tasks        = oldklass.all.to_a
        btqrubyname  = btq.name_as_ruby_class
        newklassname = "BoutiquesTask::#{btqrubyname}"

        puts_cyan "\nAdjusting tool: ID=#{tool.id} NAME=#{tool.name} PLUGIN=#{pluginname} OLDCLASS=#{oldklassname} NEWCLASS=#{newklassname} TASKS=#{tasks.size}"

        # JSON Path copying
        btq_dir = "#{pluginbase}/boutiques_descriptors"
        Dir.mkdir(btq_dir,0700) if ! File.directory?(btq_dir)
        cp_com = [ "cp","-p","#{srcpath}", "#{btq_dir}/#{jsonbase}" ]
        cp_com.unshift("echo") if action != 'upgrade'
        puts_red "Warning: there is already a BTQ descriptor in #{btq_dir}/#{jsonbase}" if File.file?("#{btq_dir}/#{jsonbase}")
        if ! system(*cp_com)
          puts_red "Could not copy '#{srcpath}' to '#{btq_dir}/#{jsonbase}' ???"
          exit 2
        end
        puts " -> JSON file '#{jsonbase}' copied in plugins '#{pluginname}'"

        # TASKS object adjustment
        inputids = btq.inputs.map(&:id)
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
          puts_yellow "AFTER: #{task.params.inspect}"                if action == 'check'
          task.update_column(:params, top)                           if action == 'upgrade'
          task.update_column(:type, "BoutiquesTask::#{btqrubyname}") if action == 'upgrade'
        end # adjust all tasks
        puts " -> Finished adjusting all tasks"

        # CustomFilter adjustments
        tcfs = TaskCustomFilter.all.select { |f| (f.data["types"] || []).include?(oldklassname) }
        puts " -> Adjusting TaskCustomFilters (#{tcfs.size})"
        tcfs.each do |tcf|
          data = tcf.data
          data["types"] -= [ oldklassname ]
          data["types"] |= [ newklassname ]
          tcf.update_column(:data, data) if action == 'upgrade'
        end

        # TOOL object adjustments
        tool.cbrain_task_class_name = newklassname
        puts " -> Adjusting TOOL class to #{newklassname}"
        tool.descriptor_name = btq.name
        tool.save! if action == 'upgrade'
        tool.addlog("Migrated to new Boutiques integrator, from #{oldklassname} to #{newklassname}")

      end # each oldtoold

      puts "All migrations finished. Remember to run the plugins install rake task if descriptors were copied!"

    end # task      cbrain:integrators:migrate



    #############################################################
    # RELINK
    #############################################################
    desc "Adjust tool configs with missing links to descriptors"
    task :relink, [:action, :tool_id] => :environment do |t,args|

      args.with_defaults(:action => 'list', :tool_id => nil)
      action     = args.action
      argtool_id = args.tool_id # could be nil

      tool=nil
      if argtool_id.present?
        if ! argtool_id.match?(/\A\d+\z/) || ! (argtool=Tool.where(:id => argtool_id).first)
          raise "Cannot find a tool with ID=#{argtool_id}"
        end
      end

      # Usage
      if action !~ /\A(list|upgrade)\z/
        puts <<-USAGE
        Usage:
          rake cbrain:integrators:relink[list]          # default
          rake cbrain:integrators:relink[list,tool_id]
          rake cbrain:integrators:migrate[upgrade]
          rake cbrain:integrators:migrate[upgrade,tool_id]

          No description yet
        USAGE
        exit 1
      end

      tools = Tool
        .where('cbrain_task_class_name like "BoutiquesTask::%"')
        .to_a

      if tools.empty?
        puts "There are no tools configured with the new integrator in this system."
        exit 1
      end

      if argtool
        if ! tools.any? { |t| t.id == argtool.id }
          puts "Error: the tool ID #{argtool_id} doesn't match any tool configured with the new integrator."
          exit 1
        end
        tools = [ argtool ]
      end

      report = tools.map do |tool|
        tot_tcs    = tool.tool_configs.where.not(:bourreau_id => nil).to_a
        unconf_tcs = tot_tcs.select { |tc| tc.boutiques_descriptor.blank? }
        next nil if unconf_tcs.empty?
        [ tool.id, tool.name, tot_tcs.count, unconf_tcs.count ]
      end.compact

      if action == 'list'
        require "hirb.rb"
        extend Hirb::Console
        prettyinfos = report.dup
        prettyinfos.unshift(["Tool ID", "Name", "Tot Configs", "Unconf Configs"])
        table prettyinfos, :headers => false, :resize => false
      end

      exit 0 if action == 'list' && argtool.blank?
      if action == 'list' # single tool report
        tool = tools.first
        tcs  = tool.tool_configs.where.not(:bourreau_id => nil).to_a
        puts_cyan "Detailed report for tool '#{tool.name}' (ID=#{tool.id}) with #{tcs.size} ToolConfigs"
        grps = tcs.group_by(&:version_name)
        report2 = grps.keys.sort.map do |vers|
          tcs = grps[vers]
          has_desc = tcs.select { |tc| tc.boutiques_descriptor.present? }
          no_desc  = tcs - has_desc
          #next nil if no_desc.blank?
          [ vers, has_desc.map(&:bourreau_id).sort, no_desc.map(&:bourreau_id).sort ]
        end
        prettyinfos = report2.dup
        prettyinfos.unshift(["Version", "Exec OK", "Exec Missing"])
        table prettyinfos, :headers => false, :resize => false
        exit 0
      end

      puts_red "TODO. The reports work though."

    end # task cbrain:integrators:relink

  end   # namespace cbrain:integrators
end     # namespace cbrain

