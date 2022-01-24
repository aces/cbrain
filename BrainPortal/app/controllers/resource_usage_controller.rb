
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

  include DateRangeRestriction

  before_action :login_required
  #before_action :admin_role_required

  AllowedReports = %w( SpaceResourceUsageForUserfile
                       SpaceResourceUsageForCbrainTask
                       CputimeResourceUsageForCbrainTask
                       WalltimeResourceUsageForCbrainTask
                     )

  # Only accessible to the admin user.
  def index #:nodoc:
    @scope      = scope_from_session

MonthlySpaceResourceUsageForUserfile
MonthlySpaceResourceUsageForCbrainTask
MonthlyCputimeResourceUsageForCbrainTask
MonthlyWalltimeResourceUsageForCbrainTask

    # We always have an implicit filter by 'type'
    type_filter = @scope.filters.detect { |f| f.attribute == 'type' }
    @maintype   = type_filter.try(:value)
    if @maintype.blank?
      @maintype   = AllowedReports.first
    end
    @scope.filters.reject! { |f| f.attribute == 'type' } # restrict_scope() below does the type filtering

    scope_default_order(@scope, 'created_at')

    @base_scope,error_mess   = restrict_scope(@maintype, @scope, params)
    flash.now[:error] = "#{error_mess}" if error_mess.present?

    @view_scope = @scope.apply(@base_scope)

    @scope.pagination ||= Scope::Pagination.from_hash({ :per_page => 15 })
    @resource_usages = @scope.pagination.apply(@view_scope) # funky plural here

    @total_plus      = @view_scope.where("resource_usage.value > 0").sum(:value)
    @total_minus     = @view_scope.where("resource_usage.value < 0").sum(:value)
    @total           = @total_plus + @total_minus

    # Re-insert a dummy filter that we use for persistency between requests
    type_filter = ViewScopes::Scope::Filter.new
    type_filter.attribute = 'type'
    type_filter.value     = @maintype
    @scope.filters.unshift(type_filter)
    scope_to_session(@scope)

    respond_to do |format|
      format.html
      format.js
    end
  end

  # Create list of RUs visible to current user.
  def base_scope() #:nodoc:
    if current_user.has_role? :admin_user
      scope = ResourceUsage.where(nil)
    else
      scope = ResourceUsage.where('resource_usage.user_id' => current_user.id)
    end
    scope
  end

  # Create list of RUs visible to current user with restricted scope
  def restrict_scope(maintype,scope,params) #:nodoc:

    @base_scope   = base_scope
                    .where('resource_usage.type' => @maintype.constantize.sti_descendants.map(&:name))
    if  @maintype == 'SpaceResourceUsageForUserfile'

      if params[:deleted_items]
        @base_scope = @base_scope.includes(:userfile).where(:userfiles => {id: nil})
      end

      if params[:negative_file_delta]
        @base_scope = @base_scope.where('resource_usage.value < 0')
      end

      if params[:positive_file_delta]
        @base_scope = @base_scope.where('resource_usage.value >= 0')
      end

    else
      if params[:deleted_items]
        @base_scope = @base_scope.includes(:cbrain_task).where(:cbrain_tasks => {id: nil})
      end
    end


    date_range     = params[:date_range]         || {}
    date_attribute = date_range[:date_attribute]

    if date_attribute == "created_at"

      # date_filtering verification
      error_mess = check_filter_date(date_attribute,
                                     date_range["absolute_or_relative_from"], date_range["absolute_or_relative_to"],
                                     date_range["absolute_from"], date_range["absolute_to"],
                                     date_range["relative_from"], date_range["relative_to"])

      if error_mess.blank?
        @base_scope = add_time_condition_to_scope(
                        @base_scope,
                        "resource_usage",
                        date_range[:absolute_or_relative_from]   == "absolute" ? true : false,
                        date_range[:absolute_or_relative_to]     == "absolute" ? true : false,
                        date_range[:absolute_from], date_range[:absolute_to],
                        date_range[:relative_from], date_range[:relative_to],
                        date_attribute)
      end
    end

    @base_scope   = @base_scope.includes( [:user, :group,
                                :userfile, :data_provider,
                                :cbrain_task, :remote_resource, :tool, :tool_config] )

    return @base_scope, error_mess
  end

end

