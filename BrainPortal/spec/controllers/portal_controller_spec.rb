
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

RSpec.describe PortalController, :type => :controller do
  let(:current_user) { create(:normal_user) }
  let(:site_manager) { create(:site_manager) }
  let(:admin_user)   { create(:admin_user) }
  let(:start_path)   { controller.send(:start_page_path) }

  context "with a logged in normal user" do

    before(:each) do
      session[:user_id]    = current_user.id
      session[:session_id] = 'session_id'
    end

    describe "welcome" do
      it "should redirect to the login page if no current_user" do
        session[:user_id] = nil
        get :welcome
        expect(response).to redirect_to(controller.send(:login_path))
      end
    end
    describe "portal_log" do
      it "should refuse a normal user" do
        get :portal_log
        expect(response.status).to eq(401)
      end
    end
    describe "show_license" do
      it "should display the appropriate licence" do
        get :show_license, params: {:license =>  "12345"}
        expect(assigns[:license]).to eq("12345")
      end
    end
    describe "sign_license" do
      it "should log the user out if the 'agree' parameter is not sent" do
        post :sign_license, params: {:license => "12345"}
        expect(response).to redirect_to "/logout"
      end
      it "should update the appropriate licence" do
        post :sign_license, params: {:license => "12345", :agree => true}
        expect(assigns[:license]).to eq("12345")
      end
      it "should redirect to the show license page if not all checkboxes were checked" do
        post :sign_license, params: {:license => "12345", :agree => true, :num_checkboxes => 1}
        expect(response).to redirect_to(:action => :show_license, :license => "12345")
      end
      it "should redirect to the start page if all checkboxes were checked" do
        post :sign_license, params: {:license => "12345", :agree => true, :num_checkboxes => 1, :license_check => "1"}
        expect(response).to redirect_to(controller.send :start_page_path)
      end
    end
  end

  context "with a logged in site manager" do

    before(:each) do
      session[:user_id] = site_manager.id
      session[:session_id] = 'session_id'
    end

    describe "welcome" do
      it "should redirect the login page" do
        get :welcome
        expect(response.status).to render_template("welcome")
      end
    end
    describe "portal_log" do
      it "should redirect the login page" do
        get :portal_log
        expect(response.status).to eq(401)
      end
    end
    describe "show_license" do
      it "should display the appropriate licence" do
        get :show_license, params: {:license =>  "12345"}
        expect(assigns[:license]).to eq("12345")
      end
    end
    describe "sign_license" do
      it "should log the user out if the 'agree' parameter is not sent" do
        post :sign_license, params: {:license => "12345"}
        expect(response).to redirect_to "/logout"
      end
      it "should update the appropriate licence" do
        post :sign_license, params: {:license => "12345", :agree => true}
        expect(assigns[:license]).to eq("12345")
      end
      it "should redirect to the show license page if not all checkboxes were checked" do
        post :sign_license, params: {:license => "12345", :agree => true, :num_checkboxes => 1}
        expect(response).to redirect_to(:action => :show_license, :license => "12345")
      end
      it "should redirect to the start page if all checkboxes were checked" do
        post :sign_license, params: {:license => "12345", :agree => true, :num_checkboxes => 1, :license_check => "1"}
        expect(response).to redirect_to(controller.send :start_page_path)
      end
    end
  end


  context "with a logged in admin user" do

     before(:each) do
        session[:user_id] = admin_user.id
        session[:session_id] = 'session_id'
        allow(IO).to receive(:popen).and_return("log")
      end

    describe "welcome" do
      it "should redirect the login page" do
        get :welcome
        expect(response.status).to render_template("welcome")
      end
    end
    describe "portal_log" do
      it "should render the portal log template" do
        get :portal_log
        expect(response).to render_template("portal_log")
      end
      it "should render the empty message is there's nothing in the log" do
        allow(IO).to receive(:popen).and_return("")
        get :portal_log
        expect(assigns[:portal_log]).to match(/No logs entries found/)
      end
    end
    describe "show_license" do
      it "should display the appropriate licence" do
        get :show_license, params: {:license =>  "12345"}
        expect(assigns[:license]).to eq("12345")
      end
    end
    describe "sign_license" do
      it "should log the user out if the 'agree' parameter is not sent" do
        post :sign_license, params: {:license => "12345"}
        expect(response).to redirect_to "/logout"
      end
      it "should update the appropriate licence" do
        post :sign_license, params: {:license => "12345", :agree => true}
        expect(assigns[:license]).to eq("12345")
      end
      it "should redirect to the show license page if not all checkboxes were checked" do
        post :sign_license, params: {:license => "12345", :agree => true, :num_checkboxes => 1}
        expect(response).to redirect_to(:action => :show_license, :license => "12345")
      end
      it "should redirect to the start page if all checkboxes were checked" do
        post :sign_license, params: {:license => "12345", :agree => true, :num_checkboxes => 1, :license_check => "1"}
        expect(response).to redirect_to(controller.send :start_page_path)
      end
    end
  end

  context "when the user is not logged in" do
    describe "welcome" do
      it "should redirect the login page" do
        get :welcome
        expect(response).to redirect_to(login_path)
      end
    end
    describe "portal_log" do
      it "should redirect the login page" do
        get :portal_log
        expect(response).to redirect_to(:controller => :sessions, :action => :new)
      end
    end
    describe "show_license" do
      it "should redirect the login page" do
        get :show_license, params: {:license =>  "12345"}
        expect(response).to redirect_to(:controller => :sessions, :action => :new)
      end
    end
    describe "sign_license" do
      it "should redirect the login page" do
        post :sign_license, params: {:license =>  "12345"}
        expect(response).to redirect_to(:controller => :sessions, :action => :new)
      end
    end
    describe "report" do
      it "should redirect the login page" do
        delete :report
        expect(response).to redirect_to(:controller => :sessions, :action => :new)
      end
    end
  end

end

