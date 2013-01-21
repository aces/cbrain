
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

require 'spec_helper'

describe SessionsController do
  let(:current_session) { double("session").as_null_object }
  let(:portal) { double("portal", :portal_locked? => false).as_null_object }
  
  before(:each) do
    BrainPortal.stub!(:current_resource).and_return(portal)
    Kernel.stub!(:sleep)
  end

  describe "new" do
    it "should render the login page" do
      get :new
      response.should render_template("new")
    end
  end
  
  describe "create" do
    let(:current_user) { mock_model(User, :account_locked? => false).as_null_object }
    
    before(:each) do
      User.stub!(:authenticate).and_return(current_user)
    end
    
    it "should render the login page if authentication fails" do
      User.stub!(:authenticate).and_return(nil)
      post :create
      response.should render_template("new")
    end
    
    it "should tell the user if authentication fails" do
      User.stub!(:authenticate).and_return(nil)
      post :create
      flash[:error].should =~ /invalid/i
    end
    
    it "should wait before completing if authentication fails" do
      User.stub!(:authenticate).and_return(nil)
      Kernel.should_receive(:sleep)
      post :create
    end
    
    it "should render the login page if the account is locked" do
      current_user.stub!(:account_locked?).and_return(true)
      post :create
      response.should render_template("new")
    end
    
    it "should render the login page if the account is locked" do
      current_user.stub!(:account_locked?).and_return(true)
      post :create
      flash[:error].should =~ /locked/i
    end
    
    it "should render the login page if the portal is locked and the user is not an admin" do
      portal.stub!(:portal_locked?).and_return(true)
      current_user.stub!(:has_role?).and_return(false)
      post :create
      response.should render_template("new")
    end
    
    it "should not render the login page if the portal is locked and the user is an admin" do
      portal.stub!(:portal_locked?).and_return(true)
      current_user.stub!(:has_role?).and_return(true)
      post :create
      response.should_not render_template("new")
    end
    
    it "should activate the session" do
      controller.stub!(:current_session).and_return(current_session)
      current_session.should_receive(:activate)
      post :create
    end
    
    it "should load user preferences" do
      controller.stub!(:current_session).and_return(current_session)
      current_session.should_receive(:load_preferences_for_user)
      post :create
    end
    
    it "should log the signing in" do
      portal.should_receive(:addlog)
      post :create
    end
    
    it "should should redirect the user to their starting page" do
      controller.should_receive(:start_page_path).and_return("/")
      post :create
    end
  end

  describe "show" do
    it "should return success status if the user is logged in" do
      controller.stub!(:current_user).and_return(Factory.create(:normal_user))
      get :show
      response.status.should == 200
    end
    it "should return unauthorized status if the user is not logged in" do
      controller.stub!(:current_user).and_return(nil)
      get :show
      response.status.should == 401
    end
  end
  
  describe "destroy" do
    let(:current_user) { Factory.create(:normal_user) }
    
    before(:each) do
      controller.stub!(:current_user).and_return(current_user)
      BrainPortal.stub!(:current_resource).and_return(portal)
    end
    
    
    it "should redirect to the login path if user not logged in" do
      controller.stub!(:current_user).and_return(nil)
      delete :destroy
      response.should redirect_to("/session/new")
    end
    
    it "should deactivate the session" do
      controller.stub!(:current_session).and_return(current_session)
      current_session.should_receive(:deactivate)
      delete :destroy
    end
    
    it "should log that the user has signed out" do
      current_user.should_receive(:addlog)
      portal.should_receive(:addlog)
      delete :destroy
    end
    
    it "should clear the session data" do
      controller.stub!(:current_session).and_return(current_session)
      current_session.should_receive(:clear_data!)
      delete :destroy
    end
    
    it "should notify the user that they've been logged out" do
      delete :destroy
      flash[:notice].should =~ /logged out/i
    end
    
    it "should redirect to the login page" do
      delete :destroy
      response.should redirect_to("/session/new")
    end
  end
end


