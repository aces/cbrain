
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

# Controller for viewing or managing exception logs.
class ExceptionLogsController < ApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  before_action :login_required
  before_action :admin_role_required

  def index #:nodoc:
    @scope = scope_from_session
    scope_default_order(@scope, 'created_at', :desc)

    @base_scope = ExceptionLog.where(nil)
    @view_scope = @scope.apply(@base_scope)

    @scope.pagination ||= Scope::Pagination.from_hash({ :per_page => 50 })
    @exception_logs = @scope.pagination.apply(@view_scope)

    scope_to_session(@scope)

    respond_to do |format|
      format.html # index.html.erb
      format.js
      format.xml  { render :xml => @exception_logs }
    end
  end

  def show #:nodoc:
    @exception_log = ExceptionLog.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @exception_log }
    end
  end

  def destroy #:nodoc:

    if params[:exception_log_ids].present?

      @exception_logs = ExceptionLog.find(params[:exception_log_ids])
      @exception_logs.each(&:destroy)

      flash[:notice] = "#{view_pluralize(@exception_logs.count, "exception")} deleted."
    else
      flash[:error] = "Please select exceptions to be deleted then hit the delete button."
    end
      respond_to do |format|
        format.html { redirect_to(:action => :index) }
        format.js   { redirect_to(:action => :index) }
        format.xml  { head :ok }
      end

  end
end
