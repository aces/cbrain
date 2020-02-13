
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

# Session management for NeuroHub
class NhsessionsController < ApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  before_action :login_required,    :except => [ :new, :create ]
  before_action :already_logged_in, :except => [ :destroy ]

  def new #:nodoc:
    # Nothing to do here now
  end

  # POST /nhsessions
  def create #:nodoc:
    username = params[:username] # in CBRAIN we use 'login'
    password = params[:password]

    all_ok, new_cb_session = eval_in_controller(::SessionsController) do
      user = User.authenticate(username,password) # can be nil if it fails
      ok   = create_from_user(user)
      [ok, cbrain_session]
    end
    @cbrain_session = new_cb_session # crush the session object that was created for the CarminController

    if ! all_ok
      redirect_to '/login'
      return
    end

    redirect_to '/home'
  end

  # GET /logout
  def destroy
    reset_session
    redirect_to '/login'
  end

  def request_password #:nodoc:
  end

  private

  def already_logged_in
    if current_user
      respond_to do |format|
        format.html { redirect_to "/welcome" }
      end
    end
  end

  # Messy utility, poking through layers. Tricky and brittle.
  # Taken from CarminController, should be extracted into a module
  def eval_in_controller(mycontroller, options={}, &block) #:nodoc:
    cb_error "Controller is not a ApplicationController?" unless mycontroller < ApplicationController
    cb_error "Block needed." unless block_given?
    context = mycontroller.new
    context.request = self.request
    if options.has_key?(:define_current_user)
      context.define_singleton_method(:current_user) { options[:define_current_user] }
    end
    context.instance_eval(&block)
  end


end
