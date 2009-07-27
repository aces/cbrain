namespace :doc do
  desc "Create CBRAIN Bourreau documentation"
  Rake::RDocTask.new(:bourreau) { |rdoc|
     rdoc.rdoc_dir = 'doc/bourreau'
     rdoc.title    = "CBRAIN Bourreau API Documentation"
     rdoc.options << '-a'
     rdoc.main = 'doc/README_FOR_APP'
     rdoc.rdoc_files.include('doc/README_FOR_APP')
     rdoc.rdoc_files.include('app/**/*.rb')
  }
end