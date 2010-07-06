namespace :doc do
  desc "Create CBRAIN Bourreau documentation"
  Rake::RDocTask.new(:bourreau) { |rdoc|
     rdoc.rdoc_dir = 'doc/bourreau'
     rdoc.title    = "CBRAIN Bourreau API Documentation"
     rdoc.options << '-a'
     rdoc.options << '-W https://cbrain.mcgill.ca/viewvc/CBRAIN/trunk/Bourreau/%s'
     rdoc.main = 'doc/README_FOR_APP'
     rdoc.rdoc_files.include('doc/README_FOR_APP')
     rdoc.rdoc_files.include('app/*/*.rb')
     rdoc.rdoc_files.include('app/models/cbrain_task/*.rb')
     rdoc.rdoc_files.include('config/initializers/cbrain.rb')
     rdoc.rdoc_files.include('config/initializers/cbrain_extensions.rb')
     rdoc.rdoc_files.include('config/initializers/revisions.rb')
     rdoc.rdoc_files.include('lib/act_rec_log.rb')
     rdoc.rdoc_files.include('lib/act_rec_meta_data.rb')
     rdoc.rdoc_files.include('lib/bourreau_system_checks.rb')
     rdoc.rdoc_files.include('lib/cbrain_checker.rb')
     rdoc.rdoc_files.include('lib/cbrain_exception.rb')
     rdoc.rdoc_files.include('lib/cbrain_transition_exception.rb')
     rdoc.rdoc_files.include('lib/recoverable_task.rb')
     rdoc.rdoc_files.include('lib/resource_access.rb')
     rdoc.rdoc_files.include('lib/restartable_task.rb')
     rdoc.rdoc_files.include('lib/scir*.rb')
     rdoc.rdoc_files.include('lib/smart_data_provider_interface.rb')
     rdoc.rdoc_files.include('lib/ssh_tunnel.rb')
  }
end

