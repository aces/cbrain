
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

# Controller implementing the CARMIN API
#
# https://github.com/CARMIN-org/CARMIN-API
class CarminController < ApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  CARMIN_revision = '0.3.1'

  api_available
  before_action :login_required, :except => [ :platform, :authenticate ]

  # GET /platform
  #
  # Information about this CARMIN platform
  def platform #:nodoc:

    portal = RemoteResource.current_resource

    platform_properties = {
      "platformName": portal.name,
      "APIErrorCodesAndMessages": [
        {
          "errorCode": 0,
          "errorMessage": "All Is Well",
          "errorDetails": {
            "additionalProp1": {}
          }
        }
      ],
      "supportedModules": [
        "Processing", "Data", "AdvancedData", "Management", "Commercial",
      ],
      "defaultLimitListExecutions": 0,
      "email":               (portal.support_email.presence || "unset@example.com"),
      "platformDescription": (portal.description.presence || ""),
      "minAuthorizedExecutionTimeout": 0,
      "maxAuthorizedExecutionTimeout": 0,
      "defaultExecutionTimeout": 0,
      "unsupportedMethods": [],
      "studiesSupport": true,
      "defaultStudy": "none",
      "supportedAPIVersion": "unknown",
      "supportedPipelineProperties": [
        "name"
      ],
      "additionalProp1": {}
    }

    respond_to do |format|
      format.json { render :json => platform_properties }
    end
  end

  # POST /authenticate
  def authenticate #:nodoc:
    username = params[:username] # in CBRAIN we use 'login'
    password = params[:password]

    context = SessionsController.new
    context.request = self.request # that's messy
    all_ok = context.instance_eval do
      user = User.authenticate(username,password) # can be nil if it fails
      create_from_user(user)
    end

    if ! all_ok
      head :unauthorized
      return
    end

    respond_to do |format|
      format.json do
        token = cbrain_session.try(:cbrain_api_token) || "badtoken"
        render :json => { :httpHeader => 'Authorization', :httpHeaderValue => "Bearer: #{token}" }
      end
    end
  end

  # GET /executions
  # I guess these are our tasks...
  def executions
    group_name = params[:studyIdentifier].presence
    offset     = params[:offset].presence
    limit      = params[:limit].presence

    if group_name
      group = current_user.available_groups.where('group.name' => group_name).first
    end

    tasks = current_user.available_tasks.real_tasks
    # Next line will purposely filter down to nothing if group_name is not a proper name for the user.
    tasks = tasks.where(:group_id => (group.try(:id) || 0)) if group_name
    tasks = tasks.order("created_at DESC")
    tasks = tasks.offset(offset.to_i) if offset
    tasks = tasks.limite(limit.to_i)  if limit
    tasks = tasks.to_a

    respond_to do |format|
      format.json do
        render :json => tasks.map(&:to_carmin)
      end
    end
  end

end
