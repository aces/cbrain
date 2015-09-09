
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

class DescriptorTaskGenerator < Rails::Generators::Base

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  source_root File.expand_path('.', __FILE__)

  argument :json_descriptor, :type => :string,
    :desc => %q{JSON descriptor to generate the CbrainTask subclass from}

  class_option :schema, :type => :string, :required => false,
    :desc => %q{JSON descriptor schema to validate the descriptor with}

  class_option :strict, :type => :boolean, :default => false,
    :desc => %q{Abort generation if the provided descriptor doesn't validate}

  def create_task #:nodoc:
    generated = SchemaTaskGenerator.generate(
      options[:schema] || SchemaTaskGenerator.default_schema,
      json_descriptor,
      options[:strict]
    )

    name, source = generated.name, generated.source
    base = "cbrain_plugins/cbrain-plugins-local/cbrain_task/#{name}"

    empty_directory "#{base}"
    empty_directory "#{base}/portal"
    empty_directory "#{base}/bourreau"
    empty_directory "#{base}/views/public"

    create_file "#{base}/portal/#{generated.name}.rb",        source[:portal]
    create_file "#{base}/bourreau/#{generated.name}.rb",      source[:bourreau]
    create_file "#{base}/views/_task_params.html.erb",        source[:task_params]
    create_file "#{base}/views/_show_params.html.erb",        source[:show_params]
    create_file "#{base}/views/public/edit_params_help.html", source[:edit_help]
  end

end
