
#
# NeuroHub Project
#
# Copyright (C) 2020
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

require 'ipaddr'

class NhSignupsController < ApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  before_action :login_required, :except => [:new, :create, :show]

  def new #:nodoc:
    @signup = Signup.new
  end

  def show #:nodoc:
  end

  def create #:nodoc:
    @signup            = Signup.new(signup_params)
    @signup.session_id = request.session_options[:id]
    @signup.generate_token

    unless can_edit?(@signup)
      redirect_to login_path
      return
    end

    if ! @signup.save
      render :action => :new
      return
    end

    sleep 1
    redirect_to nh_signups_path(@signup)
  end



  private

  def signup_params
    params.require(:signup).permit(
      :title, :first, :middle, :last,
      :institution, :department, :position, :affiliation, :email,
      :street1, :street2, :city, :province, :country, :postal_code,
      :login, :time_zone, :comment, :admin_comment, :hidden, :user_id
    )
  end

  def can_edit?(signup) #:nodoc:
    return false if signup.blank?
    return true  if signup[:session_id] == request.session_options[:id]
    return true  if current_user && current_user.has_role?(:admin_user)
    false
  end

end