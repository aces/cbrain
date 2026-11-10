namespace :db do
  namespace :local do
    task :prepare => :environment do
      unless ActiveRecord::Base.connection.table_exists?(:users)
        Rake::Task['db:schema:load'].invoke
      end
      Rake::Task['db:migrate'].invoke
      unless User.exists?(:login => 'admin')
        # Upstream seeds print a temporary password; keep that output private.
        File.open('/data/seed.log', 'w', 0600) do |log|
          original = $stdout
          begin
            $stdout = log
            load Rails.root.join('db/seeds.rb')
          ensure
            $stdout = original
          end
        end
        admin = User.find_by_login!('admin')
        password = ENV.fetch('CBRAIN_ADMIN_PASSWORD')
        admin.update!(:password => password, :password_confirmation => password)
      end
      CbrainSystemChecks.check([:a002_ensure_Rails_can_find_itself])
      RemoteResource.current_resource.update!(:dp_cache_dir => '/data/portal-cache',
        :ssh_control_host => '127.0.0.1', :ssh_control_user => 'root',
        :ssh_control_rails_dir => '/opt/cbrain/BrainPortal')
    end

    task :worker => :environment do
      worker_host = ENV.fetch('CBRAIN_WORKER_HOST')
      storage_host = ENV.fetch('CBRAIN_STORAGE_HOST')
      CbrainSystemChecks.check([:a002_ensure_Rails_can_find_itself])
      PortalSystemChecks.check([:z000_ensure_we_have_a_local_ssh_agent])
      admin = User.admin
      group = Group.everyone
      worker = Bourreau.find_or_initialize_by(:name => 'LocalBourreau')
      if worker.persisted? && (worker.ssh_control_host != worker_host || !worker.is_alive?(:ping, true))
        worker.stop_tunnels
      end
      worker.assign_attributes(:user_id => admin.id, :group_id => group.id,
        :description => 'Local Apple container UNIX worker', :online => true, :read_only => false,
        :ssh_control_host => worker_host, :ssh_control_user => 'root', :ssh_control_port => 22,
        :ssh_control_rails_dir => '/opt/cbrain/Bourreau', :cms_class => 'ScirUnix',
        :cms_shared_dir => '/data/work', :dp_cache_dir => '/data/worker-cache',
        :workers_instances => 1, :workers_chk_time => 5, :workers_log_to => 'combined', :workers_verbose => 1)
      worker.save!
      provider = DataProvider.find_by(:name => 'LocalStorage') || EnCbrainSshDataProvider.new(:name => 'LocalStorage')
      DataProvider.transaction do
        if provider.is_a?(EnCbrainLocalDataProvider) && provider.remote_dir.to_s == '/data/files'
          # The enhanced providers use the same file layout. Old cache states
          # refer to direct filesystem access and must be refreshed.
          SyncStatus.where(:userfile_id => provider.userfiles.select(:id)).delete_all
          provider = provider.becomes!(EnCbrainSshDataProvider)
        end
        abort('LocalStorage is not a compatible data provider') unless provider.is_a?(EnCbrainSshDataProvider)
        provider.update!(:user_id => admin.id, :group_id => group.id, :remote_dir => '/data/files',
          :remote_host => storage_host, :remote_user => 'root', :remote_port => 22,
          :online => true, :read_only => false, :not_syncable => false)
      end
      %w[Diagnostics Parallelizer CbSerializer].each do |name|
        tool = Tool.find_or_initialize_by(:cbrain_task_class_name => "CbrainTask::#{name}")
        tool.assign_attributes(:name => name, :user_id => admin.id, :group_id => group.id,
          :category => name == 'Diagnostics' ? 'scientific tool' : 'background',
          :select_menu_text => "Launch #{name}")
        tool.save!
        config = ToolConfig.find_or_initialize_by(:tool_id => tool.id, :bourreau_id => worker.id, :version_name => 'local')
        config.assign_attributes(:group_id => group.id, :ncpus => 1)
        config.save!
      end
      abort(worker.operation_messages) unless worker.start
      abort('Bourreau did not respond to ping') unless worker.is_alive?(:ping, true)
      worker.send_command_start_workers
      puts 'Local Bourreau is responding; processing worker started.'
    end
    task :smoke => :environment do
      CbrainSystemChecks.check([:a002_ensure_Rails_can_find_itself])
      PortalSystemChecks.check([:a000_ensure_models_are_preloaded, :z000_ensure_we_have_a_local_ssh_agent])
      worker = Bourreau.find_by_name!('LocalBourreau')
      abort('Bourreau is not responding') unless worker.is_alive?(:ping, true)
      provider = DataProvider.find_by_name!('LocalStorage')
      tool = Tool.find_by_name!('Diagnostics')
      config = ToolConfig.find_by!(:tool_id => tool.id, :bourreau_id => worker.id, :version_name => 'local')
      params = CbrainTask::Diagnostics.default_launch_args.transform_values { |v| v.is_a?(Numeric) ? v.to_s : v }
      params[:interface_userfile_ids] = []
      task = CbrainTask::Diagnostics.create!(:user_id => User.admin.id,
        :group_id => User.admin.own_group.id, :bourreau_id => worker.id,
        :tool_config_id => config.id, :results_data_provider_id => provider.id,
        :description => 'Apple container deployment smoke test', :status => 'New', :params => params)
      puts "Created Diagnostics task #{task.id}"
      worker.send_command_wakeup_workers
      90.times do
        task.reload
        if task.status == 'Completed'
          report = Userfile.find(task.params[:report_id])
          report.sync_to_cache
          abort('Diagnostics report was not saved') unless File.size?(report.cache_full_path)
          puts "PASS: task #{task.id} completed and saved report #{report.id} (#{report.name})"
          break
        end
        abort("Task #{task.id}: #{task.status}") if task.status =~ /Failed|Terminated/
        sleep 2
      end
      abort("Task #{task.id} timed out in #{task.status}") unless task.status == 'Completed'
    end
  end
end
