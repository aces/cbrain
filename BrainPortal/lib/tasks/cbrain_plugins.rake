
#
# Rake tasks for CBRAIN plugins management
#

namespace :cbrain do
  namespace :plugins do

    # Install (or re-install) plugins
    task :install do

      Dir.chdir(Rails.root + "cbrain_plugins") do
        packages = Dir.glob('*').reject { |path| path =~ /^(userfiles|cbrain_task)$/ }.select { |f| File.directory?(f) }

        # Each package

        packages.each do |package|
          puts "Checking plugins in package #{package}..."
          Dir.chdir(package) do

            # Setup each userfile plugin

            files = Dir.glob('userfiles/*').select   { |f| File.directory?(f) }
            puts "Found #{files.size} file(s) to set up..."
            files.each do |u_slash_f|                                  # "userfiles/abcd"
              myfile           = Pathname.new(u_slash_f).basename.to_s # "abcd"
              symlink_location = Pathname.new(Rails.root + "cbrain_plugins" + "userfiles" + myfile)
              plugin_location  = Pathname.new(Rails.root + "cbrain_plugins" + package + u_slash_f)
              symlink_value    = plugin_location.relative_path_from(symlink_location.parent)
              #puts "#{u_slash_f} #{myfile}\n TS=#{symlink_location}\n PL=#{plugin_location}\n LL=#{symlink_value}"

              if File.exists?(symlink_location)
                if File.symlink?(symlink_location)
                  if File.readlink(symlink_location) == symlink_value.to_s
                    puts "-> Already setup: #{myfile}"
                    next
                  end
                  puts "-> Error: there is already a symlink with an unexpected value here:\n   #{symlink_location}"
                  next
                end
                puts "-> Error: there is already an entry (file or directory) here:\n   #{symlink_location}"
                next
              end

              puts "-> Creating symlink for #{myfile}"
              File.symlink symlink_value, symlink_location
              #puts "  #{symlink_value} as #{symlink_location}"
            end


            # Setup each cbrain_task plugin

            tasks = Dir.glob('cbrain_task/*').select { |f| File.directory?(f) }
            puts "Found #{tasks.size} tasks(s) to set up..."
            tasks.each do |u_slash_t|                                  # "cbrain_task/abcd"
              mytask           = Pathname.new(u_slash_t).basename.to_s # "abcd"
              symlink_location = Pathname.new(Rails.root + "cbrain_plugins" + "cbrain_task" + mytask)
              plugin_location  = Pathname.new(Rails.root + "cbrain_plugins" + package + u_slash_t)
              symlink_value    = plugin_location.relative_path_from(symlink_location.parent)

              if File.exists?(symlink_location)
                if File.symlink?(symlink_location)
                  if File.readlink(symlink_location) == symlink_value.to_s
                    puts "-> Already setup: #{mytask}"
                    next
                  end
                  puts "-> Error: there is already a symlink with an unexpected value here:\n   #{symlink_location}"
                  next
                end
                puts "-> Error: there is already an entry (file or directory) here:\n   #{symlink_location}"
                next
              end

              puts "-> Creating symlinks for #{mytask}"
              File.symlink symlink_value, symlink_location
              File.symlink "cbrain_task_class_loader.rb", "#{symlink_location}.rb"
              #puts "  #{symlink_value} as #{symlink_location}"
            end

          end # chdir package
        end # each package
      end # chdir plugins

    end # task
  end # namespace plugins
end # namespace cbrain

