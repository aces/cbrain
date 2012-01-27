
#
# CBRAIN Project
#
# Copyright (C) 2008-2012
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

namespace :doc do
  desc "Create CBRAIN Bourreau documentation"
  Rake::RDocTask.new(:bourreau) { |rdoc|
     rdoc.rdoc_dir = 'doc/bourreau'
     rdoc.title    = "CBRAIN Bourreau API Documentation"
     rdoc.options << '-a'
     rdoc.options << '-W https://redmine.cbrain.mcgill.ca/viewvc/CBRAIN/trunk/Bourreau/%s'
     rdoc.main = 'doc/README_FOR_APP'
     rdoc.rdoc_files.include('doc/README_FOR_APP')
     rdoc.rdoc_files.include('app/*/*.rb')
     rdoc.rdoc_files.include('cbrain_plugins/cbrain_task/*/bourreau/*.rb')
     rdoc.rdoc_files.include('app/models/userfiles/*.rb')
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
     rdoc.rdoc_files.include('lib/ssh_master.rb')
  }
end

