
#
# Rake tasks for CBRAIN plugins management
#

namespace :cbrain do
  namespace :plugins do

    verbose = ENV['CBRAIN_RAKE_VERBOSE'].present? # TODO make a command-line param?

    # Unfortunately we don't have access to cbrain.rb where some useful constants are defined in the
    # CBRAIN class, such as CBRAIN::TasksPlugins_Dir ; if we ever change where plugins are stored, we
    # have to update this here and the cbrain.rb file too.
    plugins_dir             = Rails.root            + "cbrain_plugins"
    installed_plugins_dir   = plugins_dir           + "installed-plugins"
    userfiles_plugins_dir   = installed_plugins_dir + "userfiles"
    views_plugins_dir       = installed_plugins_dir + "views"
    tasks_plugins_dir       = installed_plugins_dir + "cbrain_task"
    descriptors_plugins_dir = installed_plugins_dir + "cbrain_task_descriptors"
    boutiques_plugins_dir   = installed_plugins_dir + "boutiques_descriptors"
    lib_plugins_dir         = installed_plugins_dir + "lib"

    # Paths to public assets exposed by the web server
    public_root      = Rails.root  + "public"
    public_tasks     = public_root + "cbrain_plugins/cbrain_tasks" # normally empty and part of CBRAIN dist
    public_userfiles = public_root + "cbrain_plugins/userfiles" # normally empty and part of CBRAIN dist

    # Our own formatted action logger
    logger = lambda do |action, package, type, model|
      # action is what we do to the symlink
      # package is a name such as 'cbrain-plugins-base'
      # type is either 'userfile' or 'cbrain_task' or 'descriptor'
      # model is the userfile or cbrain_task model name
      pretty_type = type ; pretty_package = package
      pretty_type    = 'file' if type =~ /userfile/i
      pretty_type    = 'task' if type =~ /task/i
      pretty_type    = 'desc' if type =~ /descriptor/i
      pretty_package = package.sub('cbrain-plugins-','')
      format = sprintf("%20s : Package=%-15s (%4s : %s)\n",action, pretty_package, pretty_type, model)
      print format
    end

    # Problematic files
    problem_files = []
    show_problem_files = lambda do
      return if problem_files.empty?
      puts "These files seem to be problematic."
      puts "You might want to clean them up manually."
      puts " -> " + problem_files.join("\n -> ")
    end



    #====================
    namespace :install do
    #====================



    ##########################################################################
    desc "Install and configure CBRAIN plugins"
    ##########################################################################
    task :all => [ :plugins, :public_assets ] do
      puts "All done."
    end



    ##########################################################################
    desc "Create the symbolic links to tasks and files found in CBRAIN plugin packages"
    ##########################################################################
    task :plugins do

      puts "Installing tasks and userfiles, as found in installed CBRAIN plugin packages..." if verbose

      Dir.chdir(plugins_dir.to_s) do
        packages = Dir.glob('*').reject { |path| path =~ /^(installed-plugins)$/ }.select { |f| File.directory?(f) }.sort

        puts "Skipping: No CBRAIN packages detected in plugins directory '#{plugins_dir}'." if verbose && packages.empty?

        # Each package
        packages.each do |package|
          puts "Checking plugins in package '#{package}'..." if verbose
          Dir.chdir(package) do

            # Setup a single unit (userfiles, tasks or descriptors)
            setup = lambda do |glob, name, directory, condition: nil, linkname: nil, after: nil|
              entries = Dir.glob(glob)
              entries.select!(&condition) if condition
              puts "Found #{entries.size} #{name}(s) to set up..." if verbose
              entries.each do |u_slash_f|
                plugin           = linkname ? linkname.(u_slash_f) : Pathname.new(u_slash_f).basename.to_s
                symlink_location = directory   + plugin
                plugin_location  = plugins_dir + package + u_slash_f
                symlink_value    = plugin_location.relative_path_from(symlink_location.parent)

                if File.exists?(symlink_location) || File.symlink?(symlink_location) # gee exists? returns false on bad symlink
                  if File.symlink?(symlink_location)
                    if File.readlink(symlink_location) == symlink_value.to_s
                      puts "-> #{name.capitalize} already setup: '#{plugin}'." if verbose
                      logger.('CodeSymlinkIsOk', package, name, plugin) if verbose
                      next
                    end
                    puts "-> Error: there is already a symlink with an unexpected value here:\n   #{symlink_location}" if verbose
                    logger.('CodeSymlinkConflict', package, name, plugin)
                    problem_files << symlink_location
                    next
                  end
                  puts "-> Error: there is already an entry (file or directory) here:\n   #{symlink_location}" if verbose
                  logger.('CodeSymlinkSpurious', package, name, plugin)
                  problem_files << symlink_location
                  next
                end

                puts "-> Creating symlink for #{name} '#{plugin}'." if verbose
                logger.('MakeCodeSymlink', package, name, plugin)
                File.symlink symlink_value, symlink_location

                after.(symlink_location) if after
              end
            end

            erase_dead_symlinks = lambda do |name, directory|
              Dir.entries(directory)
                 .map    { |entry|   [ entry, Pathname.new(directory) + entry ] }
                 .select { |_,subpath| subpath.symlink? }
                 .select { |_,subpath| ! subpath.exist? } # checks that the symlink points to something valid
                 .each  do |entry, subpath|
                    puts "-> Erasing symlink for #{name} '#{entry}'." if verbose
                    logger.('DeadSymlink', 'None', name, entry)
                    File.unlink(subpath) # remove symlink
                 end
            end

            # Setup each userfile plugin
            erase_dead_symlinks.('userfile', userfiles_plugins_dir)
            setup.('userfiles/*/*.rb', 'userfile', userfiles_plugins_dir,
              condition: lambda { |f| File.file?(f) }
            )

            # Setup the views of each userfile
            if Rails.root.to_s =~ /\/BrainPortal$/ # not needed on Bourreaux
              erase_dead_symlinks.('views', views_plugins_dir)
              setup.('userfiles/*/views', 'views', views_plugins_dir,
                linkname: lambda { |f| Pathname.new(f).parent.basename.to_s }
              )
            end

            # Setup each cbrain_task plugin
            erase_dead_symlinks.('task', tasks_plugins_dir)
            setup.('cbrain_task/*', 'task', tasks_plugins_dir,
              condition: lambda { |f| File.directory?(f) },
              after: lambda do |symlink_location|
                if ! File.symlink?("#{symlink_location}.rb")
                  File.symlink "cbrain_task_class_loader.rb", "#{symlink_location}.rb"
                end
              end
            )

            # Setup each cbrain_task descriptor plugin
            erase_dead_symlinks.('descriptor', descriptors_plugins_dir)
            setup.('cbrain_task_descriptors/*', 'descriptor', descriptors_plugins_dir,
              condition: lambda { |f| File.extname(f) == '.json' },
              after: lambda do |symlink_location|
                dest=symlink_location.to_s.sub(/.json$/, '.rb')
                if ! File.symlink?(dest)
                  File.symlink "cbrain_task_descriptor_loader.rb", dest
                end
              end
            )

            # Setup each boutiques descriptor plugin (new integrator)
            erase_dead_symlinks.('boutiques', boutiques_plugins_dir)
            setup.('boutiques_descriptors/*', 'boutiques', boutiques_plugins_dir,
              condition: lambda { |f| File.extname(f) == '.json' },
            )

            # Setup each ruby lib file
            erase_dead_symlinks.('lib', lib_plugins_dir)
            setup.('lib/*', 'lib', lib_plugins_dir,
              condition: lambda { |f| File.extname(f) == '.rb' },
            )

          end # chdir package
        end # each package
      end # chdir plugins

      show_problem_files.()

    end # task :plugins



    ##########################################################################
    desc "Create the symbolic links for public assets of installed CBRAIN tasks and userfiles."
    ##########################################################################
    task :public_assets do

      if Rails.root.to_s =~ /\/Bourreau$/
        puts "No public assets need to be installed for a Bourreau."
        next
      end

      puts "Adjusting paths to public assets for tasks and userfiles..." if verbose

      Dir.chdir(public_userfiles) do
        userfiles_public_dirs = Dir.glob(views_plugins_dir + "*/public")
        if userfiles_public_dirs.empty?
          puts "No public assets made available by any userfiles." if verbose
        else
          puts "Found #{userfiles_public_dirs.size} userfile(s) with public assets to set up..." if verbose
        end

        userfiles_public_dirs.each do |fullpath| # "/a/b/rails/cbrain_plugins/installed-plugins/views/text_file/public"
          relpath  = Pathname.new(fullpath).relative_path_from(public_userfiles) # ../(...)/cbrain_plugins/installed-plugins/views/text_file/public
          filename = relpath.parent.basename # "text_file"
          if File.exists?(filename) || File.symlink?(filename)
            if File.symlink?(filename) && (File.readlink(filename) == relpath.to_s)
              puts "-> Assets for userfile already set up: '#{filename}'." if verbose
              logger.('AssetSymlinkIsOk','(installed)','userfile',filename) if verbose
              next
            else
              puts "-> Something is in the way for assets for userfile: '#{filename}'." if verbose
              logger.('AssetSymlinkBad','(installed)','userfile',filename) if verbose
              File.unlink(filename) rescue true # let's try to cleanup.. if that fails, and exception will happen later during symlink
            end
          end
          puts "-> Creating assets symbolic link for userfile '#{filename}'." if verbose
          logger.('MakeAssetSymlink','(installed)','userfile',filename)
          File.symlink(relpath,filename)  # "text_file" -> "../(...)/cbrain_plugins/installed-plugins/userfiles/text_file/views/public"
        end
      end

      Dir.chdir(public_tasks) do
        tasks_public_dirs = Dir.glob(tasks_plugins_dir + "*/views/public")
        if tasks_public_dirs.empty?
          puts "-> No public assets made available by any tasks." if verbose
        else
          puts "Found #{tasks_public_dirs.size} task(s) with public assets to set up..." if verbose
        end

        tasks_public_dirs.each do |fullpath| # "/a/b/rails/cbrain_plugins/installed-plugins/cbrain_tasks/diagnostics/views/public"
          relpath  = Pathname.new(fullpath).relative_path_from(public_tasks) # ../(...)/cbrain_plugins/cbrain_tasks/diagnostics/views/public
          taskname = relpath.parent.parent.basename # "diagnostics"
          if File.exists?(taskname) || File.symlink?(taskname)
            if File.symlink?(taskname) && (File.readlink(taskname) == relpath.to_s)
              puts "-> Assets for task already set up: '#{taskname}'." if verbose
              logger.('AssetSymlinkIsOk','(installed)','task',taskname) if verbose
              next
            else
              puts "-> Something is in the way for assets for tasks: '#{taskname}'." if verbose
              logger.('AssetSymlinkBad','(installed)','task',taskname) if verbose
              File.unlink(taskname) rescue true # let's try to cleanup.. if that fails, and exception will happen later during symlink
            end
          end
          puts "-> Creating assets symbolic link for task '#{taskname}'." if verbose
          logger.('MakeAssetSymlink','(installed)','task',taskname)
          File.symlink(relpath,taskname)  # "diagnostics" -> "../(...)/cbrain_plugins/installed-plugins/cbrain_tasks/diagnostics/views/public"
        end
      end

      # Generate help files for Boutiques tasks
      # Note: changes here should be synced with SchemaTaskGenerator if necessary
      Rake::Task["environment"].invoke

      Dir.chdir(descriptors_plugins_dir) do
        helpFileDir = File.join( "cbrain_plugins", "cbrain_tasks", "help_files/" )
        basePath    = Rails.root.join( File.join('public/', helpFileDir) )
        FileUtils.mkdir_p( basePath.to_s ) # creates directory if needed
        schema = SchemaTaskGenerator.default_schema # read in the Boutiques schema
        # For each JSON decriptor of a tool, write a help file
        Dir.glob("*").select { |f| f.end_with? '.json' }.each do |f|
          absFile = File.absolute_path(f.to_s)
          # Generate the task from the templates and JSON descriptor
          generatedTask = SchemaTaskGenerator.generate(schema, absFile)
          next if generatedTask.nil? # this happens with bad descriptors
          helpFileName  = SchemaTaskGenerator.classify(generatedTask.name) + "_help.html"
          helpFilePath  = basePath.join(helpFileName).to_s
          # Prevent broken symlinks from stopping the whole rake task
          next unless File.exist?(File.realpath( absFile ))
          # Write the help file
          File.open( helpFilePath , "w" ){ |h|
            h.write( generatedTask.source[:edit_help] )
          }
          FileUtils.chmod(0775, helpFilePath)
        end
      end

    end # task :public_assets

    end # namespace install




    #====================
    namespace :clean do
    #====================



    ##########################################################################
    desc "Clean all CBRAIN plugins installation symlinks "
    ##########################################################################
    task :all => [ :plugins, :public_assets ] do
      puts "All done. You might want to run the rake task 'cbrain:plugins:install:all' now to reinstall everything properly."
    end



    ##########################################################################
    desc "Clean up symbolic links for tasks and userfiles of CBRAIN plugin packages"
    ##########################################################################
    task :plugins do

      erase = lambda do |name, dir|
        puts "Erasing all symlinks for #{name.pluralize} installed from CBRAIN plugins..." if verbose
        Dir.chdir(dir.to_s) do
          Dir.glob('*').select { |f| File.symlink?(f) }.each do |f|
            puts "-> Erasing link for #{name} '#{f}'." if verbose
            logger.('EraseCodeSymlink', '(installed)', name, f)
            File.unlink(f)
          end
        end
      end

      erase.('userfile',   userfiles_plugins_dir)
      erase.('views',      views_plugins_dir)
      erase.('task',       tasks_plugins_dir)
      erase.('descriptor', descriptors_plugins_dir)
      erase.('boutiques',  boutiques_plugins_dir)
      erase.('lib',        lib_plugins_dir)

    end



    ##########################################################################
    desc "Clean up symbolic links for public assets of installed CBRAIN tasks and userfiles."
    ##########################################################################
    task :public_assets do

      if Rails.root.to_s =~ /\/Bourreau$/
        puts "No public assets need to be cleaned for a Bourreau."
        next
      end

      puts "Erasing all symlinks for public assets of userfiles installed from CBRAIN plugins..." if verbose
      Dir.chdir(public_userfiles.to_s) do
        Dir.glob('*').select { |f| File.symlink?(f) }.each do |f|
          puts "-> Erasing link for assets of userfile '#{f}'." if verbose
          logger.('EraseAssetSymlink', '(installed)', 'userfile', f)
          File.unlink(f)
        end
      end

      puts "Erasing all symlinks for public assets of tasks installed from CBRAIN plugins..." if verbose
      Dir.chdir(public_tasks.to_s) do
        Dir.glob('*').select { |f| File.symlink?(f) }.each do |f|
          puts "-> Erasing link for assets of task '#{f}'." if verbose
          logger.('EraseAssetSymlink', '(installed)', 'task', f)
          File.unlink(f)
        end
      end

    end



    ##########################################################################
    desc "Remove leftover (orphan) tasks and userfiles from removed CBRAIN plugins"
    ##########################################################################
    task :orphans => :environment do

      # We'll need all available userfile and task models
      CbrainSystemChecks.check([:a002_ensure_Rails_can_find_itself])
      Rails.application.eager_load!

      # Available userfile and task types
      userfile_classes = Userfile.descendants.map(&:name)
      task_classes     = CbrainTask.descendants.map(&:name)

      raise "Error: cannot find any userfile subclasses?!?" if userfile_classes.blank?
      raise "Error: cannot find any task subclasses?!?"     if task_classes.blank?

      puts "Removing orphan userfiles..."
      Userfile
        .where("type not in (?)", userfile_classes)
        .update_all(:type => "Userfile")
      deleted_userfiles = Userfile
        .destroy_all(:type => "Userfile")
        .count

      puts "Removing orphan tasks..."
      CbrainTask
        .where("type not in (?)", task_classes)
        .update_all(:type => "CbrainTask")
      deleted_tasks = CbrainTask
        .destroy_all(:type => "CbrainTask")
        .count

      if deleted_userfiles == 0 && deleted_tasks == 0
        puts "No orphans (userfile or task) found."
      else
        deleted = deleted_userfiles + deleted_tasks
        puts "#{deleted} orphan(s) (#{deleted_userfiles} userfile(s) and #{deleted_tasks} task(s)) removed."
      end

    end

    end # namespace clean




    #====================
    namespace :check do
    #====================



    ##########################################################################
    desc "Check for leftover (orphan) tasks or userfiles from removed CBRAIN plugins"
    ##########################################################################
    task :orphans => :environment do

      # We'll need all available userfile and task models
      CbrainSystemChecks.check([:a002_ensure_Rails_can_find_itself])
      Rails.application.eager_load!

      # Available userfile and task types
      userfile_classes = Userfile.descendants.map(&:name)
      task_classes     = CbrainTask.descendants.map(&:name)

      raise "Error: cannot find any userfile subclasses?!?" if userfile_classes.blank?
      raise "Error: cannot find any task subclasses?!?"     if task_classes.blank?

      puts "Checking for orphan userfiles..."
      orphan_userfiles = Userfile
        .where("type not in (?)", userfile_classes)
        .pluck(:id, :type)
      unless orphan_userfiles.empty?
        puts "#{orphan_userfiles.size} orphan userfile(s) found:"
        orphan_userfiles.each do |orphan|
          puts "-> id: #{orphan[0]}, type: #{orphan[1]}"
        end
      end

      puts "Checking for orphan tasks..."
      orphan_tasks = CbrainTask
        .where("type not in (?)", task_classes)
        .pluck(:id, :type)
      unless orphan_tasks.empty?
        puts "#{orphan_tasks.size} orphan task(s) found:"
        orphan_tasks.each do |orphan|
          puts "-> id: #{orphan[0]}, type: #{orphan[1]}"
        end
      end

      if orphan_userfiles.empty? && orphan_tasks.empty?
        puts "No orphans (userfile or task) found."
      else
        puts "Please run 'rake cbrain:plugins:clean:orphans' to remove orphan tasks and userfiles."
      end
    end




    end # namespace check
  end # namespace plugins
end # namespace cbrain


