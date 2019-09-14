
#
# CBRAIN Project
#
# Copyright (C) 2008-2019
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

# Tracks creation, delete, increases and decreases of various
# resources (e.g. bytes for userfiles, seconds for tasks etc)
# Summing values for incompatible types are of course meaningless.
class ResourceUsage < ApplicationRecord

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  self.table_name = 'resource_usage' # no pluralize here!

  cbrain_abstract_model! # objects of this class are not to be instanciated

  validates_presence_of :value

  belongs_to            :user,            optional: true
  belongs_to            :group,           optional: true
  belongs_to            :userfile,        optional: true
  belongs_to            :data_provider,   optional: true
  belongs_to            :cbrain_task,     optional: true
  belongs_to            :remote_resource, optional: true
  belongs_to            :tool,            optional: true
  belongs_to            :tool_config,     optional: true

  before_save :record_names_and_types

  # If any of the "_id" attributes are provided,
  # the we also automatically fill in the duplicated
  # information that we keep about the associated object.
  def record_names_and_types #:nodoc:
    if self.user
      self.user_type            ||= self.user.type
      self.user_login           ||= self.user.login
    end

    if self.group
      self.group_type           ||= self.group.type
      self.group_name           ||= self.group.name
    end

    if self.userfile
      self.userfile_type        ||= self.userfile.type
      self.userfile_name        ||= self.userfile.name
      self.data_provider_id     ||= self.userfile.data_provider.id
    end

    if self.data_provider
      self.data_provider_type   ||= self.data_provider.type
      self.data_provider_name   ||= self.data_provider.name
    end

    if self.cbrain_task
      self.cbrain_task_type     ||= self.cbrain_task.type
      self.cbrain_task_status   ||= self.cbrain_task.status
    end

    if self.remote_resource
      self.remote_resource_name ||= self.remote_resource.name
    end

    if self.tool
      self.tool_name            ||= self.tool.name
    end

    if self.tool_config
      self.tool_config_version_name ||= self.tool_config.version_name
    end
  end

end

