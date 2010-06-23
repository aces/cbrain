namespace :doc do
  desc "Create CBRAIN BrainPortal documentation"
  Rake::RDocTask.new(:brainportal) { |rdoc|
     rdoc.rdoc_dir = 'doc/brainportal'
     rdoc.title    = "CBRAIN BrainPortal API Documentation"
     rdoc.options << '-a'
     rdoc.options << '-W https://cbrain.mcgill.ca/viewvc/CBRAIN/trunk/BrainPortal/%s'
     rdoc.main = 'doc/README_FOR_APP'
     rdoc.rdoc_files.include('doc/README_FOR_APP')
     rdoc.rdoc_files.include('app/*/*.rb')
     rdoc.rdoc_files.include('app/models/cbrain_task/*.rb')
     rdoc.rdoc_files.include('config/initializers/cbrain.rb')
     rdoc.rdoc_files.include('config/initializers/revisions.rb')
     rdoc.rdoc_files.include('config/initializers/logging.rb')
     rdoc.rdoc_files.include('config/initializers/meta_data.rb')
     rdoc.rdoc_files.include('lib/cbrain_checker.rb')
     rdoc.rdoc_files.include('lib/cbrain_exception.rb')
     rdoc.rdoc_files.include('lib/cbrain_task_logging.rb')
     rdoc.rdoc_files.include('lib/cbrain_transition_exception.rb')
     rdoc.rdoc_files.include('lib/portal_sanity_checks.rb')
     rdoc.rdoc_files.include('lib/portal_system_checks.rb')
     rdoc.rdoc_files.include('lib/resource_access.rb')
     rdoc.rdoc_files.include('lib/smart_data_provider_interface.rb')
     rdoc.rdoc_files.include('lib/ssh_tunnel.rb')
  }
end

