
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

class AddNewRemoteResourceAttributes < ActiveRecord::Migration

  def self.up

    # Portal only
    add_column :remote_resources, :site_url_prefix,        :string

    # All RemoteResources
    add_column :remote_resources, :dp_cache_dir,           :string
    add_column :remote_resources, :dp_ignore_patterns,     :text

    # Bourreau only, Cluster Management System values
    add_column :remote_resources, :cms_class,              :string
    add_column :remote_resources, :cms_default_queue,      :string
    add_column :remote_resources, :cms_extra_qsub_args,    :string
    add_column :remote_resources, :cms_shared_dir,         :string

    # Bourreau only, Workers info
    add_column :remote_resources, :workers_instances,      :integer
    add_column :remote_resources, :workers_chk_time,       :integer
    add_column :remote_resources, :workers_log_to,         :string
    add_column :remote_resources, :workers_verbose,        :integer
     
  end

  def self.down

    # Portal only
    remove_column :remote_resources, :site_url_prefix

    # All RemoteResources
    remove_column :remote_resources, :dp_cache_dir
    remove_column :remote_resources, :dp_ignore_patterns

    # Bourreau only, Cluster Management System values
    remove_column :remote_resources, :cms_class
    remove_column :remote_resources, :cms_default_queue
    remove_column :remote_resources, :cms_extra_qsub_args
    remove_column :remote_resources, :cms_shared_dir

    # Bourreau only, Workers info
    remove_column :remote_resources, :workers_instances
    remove_column :remote_resources, :workers_chk_time
    remove_column :remote_resources, :workers_log_to
    remove_column :remote_resources, :workers_verbose
     
  end

end

