
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

# Controller for managing ResourceUsage objects.
class ResourceUsageController < ApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  before_action :login_required
  before_action :admin_role_required

  AllowedReports = %w( SpaceResourceUsageForUserfile
                       SpaceResourceUsageForCbrainTask
                       CputimeResourceUsageForCbrainTask
                       WalltimeResourceUsageForCbrainTask
                     )

  # Only accessible to the admin user.
  def index #:nodoc:
    @scope      = scope_from_session

    # We always have an implicit filter by 'type'
    type_filter = @scope.filters.detect { |f| f.attribute == 'type' }
    @maintype   = type_filter.try(:value)
    if @maintype.blank?
      @maintype   = AllowedReports.first
      type_filter = ViewScopes::Scope::Filter.new
      type_filter.attribute = 'type'
      type_filter.value     = @maintype
      @scope.filters.unshift(type_filter)
    end

    scope_default_order(@scope, 'created_at')

    @base_scope   = base_scope
                    .where('resource_usage.type' => @maintype)
                    .includes( [:user, :group,
                                :userfile, :data_provider,
                                :cbrain_task, :remote_resource, :tool, :tool_config] )
    @view_scope   = @scope.apply(@base_scope)

    @scope.pagination ||= Scope::Pagination.from_hash({ :per_page => 15 })
    @resource_usages = @scope.pagination.apply(@view_scope) # funky plural here

    @total_plus      = @view_scope.where("resource_usage.value > 0").sum(:value)
    @total_minus     = @view_scope.where("resource_usage.value < 0").sum(:value)
    @total           = @total_plus + @total_minus

    respond_to do |format|
      format.html
      format.js
    end
  end

  # Create list of RUs visible to current user.
  def base_scope() #:nodoc:
    scope = ResourceUsage.where(nil)
    scope
  end

end

