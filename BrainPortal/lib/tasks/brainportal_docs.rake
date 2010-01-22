namespace :doc do
  desc "Create CBRAIN BrainPortal documentation"
  Rake::RDocTask.new(:brainportal) { |rdoc|
     rdoc.rdoc_dir = 'doc/brainportal'
     rdoc.title    = "CBRAIN BrainPortal API Documentation"
     rdoc.options << '-a'
     rdoc.main = 'doc/README_FOR_APP'
     rdoc.rdoc_files.include('doc/README_FOR_APP')
     rdoc.rdoc_files.include('app/**/*.rb')
     rdoc.rdoc_files.include('config/initializers/cbrain.rb')
     rdoc.rdoc_files.include('config/initializers/revisions.rb')
     rdoc.rdoc_files.include('config/initializers/logging.rb')
     rdoc.rdoc_files.include('lib/ssh_tunnel.rb')
  }
end
  
