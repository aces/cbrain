
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

require 'rails_helper'

RSpec.describe SessionsController, :type => :controller do
  let(:current_session) { mock_model(ActiveRecord::SessionStore::Session, "_csrf_token" => 'dummy csrf').as_null_object }
  let(:portal)          { double("portal", :portal_locked? => false).as_null_object }

  before(:each) do
    allow(BrainPortal).to receive(:current_resource).and_return(portal)
    allow(Kernel).to      receive(:sleep)
  end

  describe "new" do
    it "should render the login page" do
      get :new
      expect(response).to render_template("new")
    end
  end

  describe "create" do
    let(:current_user) { mock_model(User, :account_locked? => false).as_null_object }

    before(:each) do
      allow(User).to         receive(:authenticate).and_return(current_user)
      allow(current_user).to receive(:meta).and_return({})
      allow(controller).to receive(:current_session).and_return(current_session)
    end

    it "should render the login page if authentication fails" do
      allow(User).to receive(:authenticate).and_return(nil)
      post :create
      expect(response).to render_template("new")
    end

    it "should tell the user if authentication fails" do
      allow(User).to receive(:authenticate).and_return(nil)
      post :create
      expect(flash[:error]).to match(/invalid/i)
    end

    it "should wait before completing if authentication fails" do
      allow(User).to receive(:authenticate).and_return(nil)
      expect(Kernel).to receive(:sleep)
      post :create
    end

    it "should render the login page if the account is locked" do
      allow(current_user).to receive(:account_locked?).and_return(true)
      post :create
      expect(response).to render_template("new")
    end

    it "should display an error if the user account is locked" do
      allow(current_user).to receive(:account_locked?).and_return(true)
      post :create
      expect(flash[:error]).to match(/locked/i)
    end

    it "should render the login page if the portal is locked and the user is not an admin" do
      allow(portal).to       receive(:portal_locked?).and_return(true)
      allow(current_user).to receive(:has_role?).and_return(false)
      post :create
      expect(response).to render_template("new")
    end

    it "should not render the login page if the portal is locked and the user is an admin" do
      allow(portal).to       receive(:portal_locked?).and_return(true)
      allow(current_user).to receive(:has_role?).and_return(true)
      allow(controller).to   receive(:user_tracking)
      post :create
      expect(response).not_to render_template("new")
    end

    it "should activate the session" do
      expect(current_session).to receive(:activate)
      post :create
    end

    it "should log the signing in" do
      expect(portal).to receive(:addlog)
      post :create
    end

    it "should should redirect the user to their starting page" do
      expect(controller).to receive(:start_page_path).and_return("/")
      post :create
    end
  end

  describe "show" do
    it "should return success status if the user is logged in" do
      allow(controller).to receive(:current_user).and_return(create(:normal_user))
      get :show
      expect(response.status).to eq(200)
    end
    it "should return unauthorized status if the user is not logged in" do
      allow(controller).to receive(:current_user).and_return(nil)
      get :show
      expect(response.status).to eq(401)
    end
  end

  describe "destroy" do
    let(:current_user) { create(:normal_user) }

    before(:each) do
      allow(controller).to receive(:current_user).and_return(current_user)
      allow(BrainPortal).to receive(:current_resource).and_return(portal)
    end


    it "should redirect to the login path if user not logged in" do
      allow(controller).to receive(:current_user).and_return(nil)
      delete :destroy
      expect(response).to redirect_to("/session/new")
    end

    it "should deactivate the session" do
      allow(controller).to receive(:current_session).and_return(current_session)
      expect(current_session).to receive(:deactivate)
      delete :destroy
    end

    it "should log that the user has signed out" do
      expect(current_user).to receive(:addlog)
      expect(portal).to receive(:addlog)
      delete :destroy
    end

    it "should clear the session data" do
      allow(controller).to receive(:current_session).and_return(current_session)
      expect(current_session).to receive(:clear)
      delete :destroy
    end

    it "should notify the user that they've been logged out" do
      delete :destroy
      expect(flash[:notice]).to match(/logged out/i)
    end

    it "should redirect to the login page" do
      delete :destroy
      expect(response).to redirect_to("/session/new")
    end
  end
end


