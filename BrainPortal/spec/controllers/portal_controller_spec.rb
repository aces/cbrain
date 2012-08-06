
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

describe PortalController do
  let(:current_user) {Factory.create(:normal_user)}
  let(:admin_user) {Factory.create(:admin_user)}
  
  context "with a logged in normal user" do
    before(:each) do
      session[:user_id] = current_user.id
    end

    describe "welcome" do
      it "should find the default data provider" do
        DataProvider.should_receive(:find_by_id)
        get :welcome
      end
      it "should find the default bourreau" do
        Bourreau.should_receive(:find_by_id)
        get :welcome
      end
      it "should get a list of recent tasks" do
        task_list = double("task_list").as_null_object
        CbrainTask.stub_chain(:real_tasks, :not_archived, :where, :order, :limit, :all).and_return(task_list)
        get :welcome
        assigns[:tasks].should == task_list
      end
    end
    describe "portal_log" do
      it "should redirect the login page" do
        get :portal_log
        response.status.should == 401
      end
    end
    describe "show_license" do
      it "should display the appropriate licence" do
        get :show_license, :license =>  "12345"
        assigns[:license].should == "12345"
      end
    end
    describe "sign_license" do
      it "should log the user out if the 'agree' parameter is not sent" do
        post :sign_license, :license => "12345"
        response.should redirect_to "/logout"
      end
      it "should update the appropriate licence" do
        post :sign_license, :license => "12345", :agree => true
        assigns[:license].should == "12345"
      end
      it "should redirect to the show license page if not all checkboxes were checked" do
        post :sign_license, :license => "12345", :agree => true, :num_checkboxes => 1
        response.should redirect_to(:action => :show_license, :license => "12345")
      end
      it "should redirect to the start page if all checkboxes were checked" do
        post :sign_license, :license => "12345", :agree => true, :num_checkboxes => 1, :license_check => "1"
        response.should redirect_to(controller.send :start_page_path)
      end
    end
  end
    
  context "with a logged in admin user" do
    before(:each) do
      session[:user_id] = admin_user.id
      IO.stub!(:popen).and_return("log")
    end
    
    describe "portal_log" do
      it "should render the portal log template" do
        get :portal_log
        response.should render_template("portal_log")
      end
      it "should render the empty message is there's nothing in the log" do
        IO.stub!(:popen).and_return("")
        get :portal_log
        assigns[:portal_log].should include_text(/No logs entries found/)
      end
    end
    
  end
 
  context "when the user is not logged in" do
    describe "welcome" do
      it "should redirect the login page" do
        get :welcome
        response.should redirect_to(login_path)
      end
    end
    describe "portal_log" do
      it "should redirect the login page" do
        get :portal_log
        response.should redirect_to(:controller => :sessions, :action => :new)
      end
    end
    describe "show_license" do
      it "should redirect the login page" do
        get :show_license, :license =>  "12345"
        response.should redirect_to(:controller => :sessions, :action => :new)
      end
    end
    describe "sign_license" do
      it "should redirect the login page" do
        post :sign_license, :license =>  "12345"
        response.should redirect_to(:controller => :sessions, :action => :new)
      end
    end
    describe "report" do
      it "should redirect the login page" do
        delete :report
        response.should redirect_to(:controller => :sessions, :action => :new)
      end
    end
  end
  
end

