
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

class ClusterTaskGenerator < Rails::Generators::Base
    
  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  source_root File.expand_path("../templates", __FILE__)

  argument     :file_or_class, :type => :string,  :default => "application"  
  class_option :advanced,      :type => :boolean, :default => false
  class_option :license,       :type => :string,  :required => false, :default => ""

  def create_task
    license = options[:license]
    @_license_text = ""
    if license.present?
      raise "Error: can't find license file: #{license}" if !File.exist?(license)
      @_license_text = File.read(license)      
    end
    empty_directory "cbrain_plugins/cbrain_task/#{file_name}"
    empty_directory "cbrain_plugins/cbrain_task/#{file_name}/portal"
    empty_directory "cbrain_plugins/cbrain_task/#{file_name}/bourreau"
    empty_directory "cbrain_plugins/cbrain_task/#{file_name}/common"
    empty_directory "cbrain_plugins/cbrain_task/#{file_name}/views"
    template "portal_task_model.rb",   "cbrain_plugins/cbrain_task/#{file_name}/portal/#{file_name}.rb"
    template "bourreau_task_model.rb", "cbrain_plugins/cbrain_task/#{file_name}/bourreau/#{file_name}.rb"
    template "common_task_model.rb",   "cbrain_plugins/cbrain_task/#{file_name}/common/#{file_name}.rb"
    template "task_params.html.erb",   "cbrain_plugins/cbrain_task/#{file_name}/views/_task_params.html.erb"
    template "show_params.html.erb",   "cbrain_plugins/cbrain_task/#{file_name}/views/_show_params.html.erb"
    template "task_options.html.erb",  "public/doc/tasks/#{file_name}_options.html"
    if File.exists?("cbrain_plugins/cbrain_task/#{file_name}.rb")
      #logger.exists "cbrain_plugins/cbrain_task/#{file_name}.rb"
    else
      #logger.create "cbrain_plugins/cbrain_task/#{file_name}.rb"
      File.symlink  "cbrain_task_class_loader.rb", "cbrain_plugins/cbrain_task/#{file_name}.rb"
    end
  end

  def file_name
    @_file_name ||= file_or_class.underscore
  end

  def class_name
    @_class_name ||= file_or_class.classify
  end
  
end

