
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

# JSON/XML controller for server-side session data, such as filters, sorting
# options, selections, etc.
class SessionDataController < ApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  api_available
  before_filter :login_required

  # GET /session_data
  def show #:nodoc:
    @session = current_session.to_h.reject do |k,v|
      CbrainSession.internal_keys.include?(k)
    end

    respond_to do |format|
      format.xml  { render :xml  => @session }
      format.json { render :json => @session }
    end
  end

  # POST /session_data
  def update #:nodoc:
    mode    = request.query_parameters[:mode].to_sym rescue :replace
    changes = request.request_parameters.reject do |k,v|
      CbrainSession.internal_keys.include?(k)
    end

    current_session.update(changes, mode)
    show

  rescue => ex
    respond_to do |format|
      format.xml  { render :xml  => { :error => ex.message }, :status => :unprocessable_entity }
      format.json { render :json => { :error => ex.message }, :status => :unprocessable_entity }
    end
  end

end
