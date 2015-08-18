
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

class CbrainTaskGenerator < Rails::Generators::Base

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  source_root File.expand_path("../templates", __FILE__)

  argument     :file_or_class, :type => :string,  :default => "application"
  class_option :advanced,      :type => :boolean, :default => false
  class_option :license,       :type => :string,  :required => false, :default => ""
  class_option :plugin_name,   :type => :string,  :required => false, :default => "local"

  def create_task #:nodoc:
    license = options[:license]
    plugin  = options[:plugin_name]
    @_license_text = ""
    if license.present?
      raise "Error: can't find license file: #{license}" if !File.exist?(license)
      @_license_text = File.read(license)
    end
    task_dir      = "cbrain_plugins/cbrain-plugins-#{plugin}/cbrain_task/#{file_name}"
    empty_directory "#{task_dir}"
    empty_directory "#{task_dir}/portal"
    empty_directory "#{task_dir}/bourreau"
    empty_directory "#{task_dir}/common"
    empty_directory "#{task_dir}/views"
    empty_directory "#{task_dir}/views/public"
    template "portal_task_model.rb",      "#{task_dir}/portal/#{file_name}.rb"
    template "bourreau_task_model.rb",    "#{task_dir}/bourreau/#{file_name}.rb"
    template "common_task_model.rb",      "#{task_dir}/common/#{file_name}.rb"
    template "task_params.html.erb",      "#{task_dir}/views/_task_params.html.erb"
    template "show_params.html.erb",      "#{task_dir}/views/_show_params.html.erb"
    template "edit_params_help.html.erb", "#{task_dir}/views/public/edit_params_help.html"
    template "tool_info.html.erb",        "#{task_dir}/views/public/tool_info.html"
  end

  def file_name #:nodoc:
    @_file_name ||= file_or_class.underscore
  end

  def class_name #:nodoc:
    @_class_name ||= file_or_class.classify
  end

end

