
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

# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base #:nodoc:

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  helper :all # include all helpers, all the time

  # Patch
  def self.api_available #:nodoc:
    true
  end

  # See ActionController::RequestForgeryProtection for details
  # Uncomment the :secret if you're not using the cookie session store
  #protect_from_forgery # :secret => '1ffec2733b8e6fe4baef5e8b84db95b8'

  # See ActionController::Base for details
  # Uncomment this to filter the contents of submitted sensitive data parameters
  # from your application log (in this case, all fields with names like "password").
  # filter_parameter_logging :password

  #Patch: Load all models so single-table inheritance works properly.
  begin
    Dir.chdir(File.join(Rails.root.to_s, "app", "models")) do
      Dir.glob("*.rb").each do |model|
        model.sub!(/.rb$/,"")
        require_dependency "#{model}.rb" unless Object.const_defined? model.classify
      end
    end
  rescue => error
    if error.to_s.match(/Mysql::Error.*Table.*doesn't exist/i)
      puts "Skipping model load:\n\t- Database table doesn't exist yet. It's likely this system is new and the migrations have not been run yet."
    elsif error.to_s.match(/Unknown database/i)
      puts "Skipping model load:\n\t- System database doesn't exist yet. It's likely this system is new and the migrations have not been run yet."
    else
      raise
    end
  end

end

