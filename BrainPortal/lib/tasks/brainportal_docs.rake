namespace :doc do
  desc "Create CBRAIN BrainPortal documentation"
  Rake::RDocTask.new(:brainportal) { |rdoc|
     rdoc.rdoc_dir = 'doc/brainportal'
     rdoc.title    = "CBRAIN BrainPortal API Documentation"
     rdoc.options << '-a' << '-U'
     rdoc.main = 'doc/README_FOR_APP'
     rdoc.rdoc_files.include('doc/README_FOR_APP')
     rdoc.rdoc_files.include('app/**/*.rb')
  }
end
  