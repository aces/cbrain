
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

RSpec.describe ToolsController, :type => :controller do
  let(:mock_tool)    { mock_model(Tool).as_null_object }
  let!(:real_tool_1) { create(:tool, :name => "fake_tool1") }
  let!(:real_tool_2) { create(:tool, :name => "fake_tool2") }
  tool = FactoryBot.attributes_for(:tool)


  context "with a logged in user" do
    context "user is an admin" do
      let(:admin_user) {  create(:admin_user) }
      before(:each) do
        allow(controller).to receive(:current_user).and_return(admin_user)
        session[:session_id] = 'session_id'
      end

      describe "index", :current => true do

        it "should assign @tools with all tools included new one" do
          get :index
          expect(assigns[:tools]).to include(real_tool_1, real_tool_2)
        end
        it "should render the index page" do
          get :index
          expect(response).to render_template("index")
        end
      end

      describe "bourreau_select" do
        it "should render empty text if tool_id is empty" do
          get(:tool_config_select, params: {'tool_id' => ""})
          expect(response.body).to be_empty
        end

        it "should render bourreau_select" do
          get(:tool_config_select, params: {'tool_id' => real_tool_1.id.to_s})
          expect(response).to render_template("tools/_tool_config_select")
        end

        it "should display error text if go in rescue" do
          get(:tool_config_select, params: {'tool_id' => "abc"})
          expect(response.body).to match(/No Execution Servers/)
        end
      end

      describe "create" do

        it "should autoload_all_tools if autoload is defined" do
          allow(controller).to  receive(:render)
          expect(controller).to receive(:autoload_all_tools)
          post :create, params: {tool: tool, autoload: "true", format: "js"}
        end

        context "when save is successful" do
          before(:each) do
            allow(Tool).to receive(:new).and_return(mock_tool)
            allow(mock_tool).to receive_message_chain(:errors, :add)
            allow(mock_tool).to receive(:save).and_return(true)
            allow(mock_tool).to receive_message_chain(:errors, :empty?).and_return(true)
          end

          it "should send a flash notice" do
            post :create, params: {tool: tool}
            expect(flash[:notice]).to  be_truthy
          end
          it "should redirect to the index" do
            post(:create, params: {tool: {:name => "name", format: 'html'}})
            expect(response).to redirect_to(:action => :index, :format => :html)
          end
        end

        context "when save failed" do
          before(:each) do
            allow(Tool).to receive(:new).and_return(mock_tool)
            allow(mock_tool).to receive_message_chain(:errors, :add)
            allow(mock_tool).to receive(:save).and_return(false)
            allow(mock_tool).to receive_message_chain(:errors, :empty?).and_return(false)
          end

        end

      end

      describe "update" do

        it "should find available tools" do
          put :update, params: {id: real_tool_1.id, tool: tool}
          expect(assigns[:tool]).to eq(real_tool_1)
        end

        context "when update is successful" do
          it "should display a flash message" do
            put :update, params: {id: real_tool_1.id, tool: tool}
            expect(flash[:notice]).to eq("Tool was successfully updated.")
          end
        end

        context "when update fails" do

          it "should render the edit page" do
            put :update, params: {id: real_tool_1.id, tool: {:name => ""}}
            expect(response).to render_template("edit")
          end
        end
      end

      describe "destroy" do

        it "should find the requested tag" do
          delete :destroy, params: {id: real_tool_1.id}
          expect(assigns[:tool]).to eq(real_tool_1)
        end
        it "should allow me to destroy a tool" do
          delete :destroy, params: {id: real_tool_1.id}
          expect(Tool.all).not_to include(real_tool_1)
        end
        it "should redirect to the index" do
          delete :destroy, params: {id: real_tool_1.id, format: "js"}
          expect(response).to redirect_to(:action => :index, :format => :js)
        end
      end

    end

    context "user is a standard user" do
      let(:normal_user) { create(:normal_user) }
      before(:each) do
        allow(controller).to receive(:current_user).and_return(normal_user)
        session[:session_id] = 'session_id'
      end

      describe "index" do
        it "should assign @tools with all tools avaible for this user" do
          allow(normal_user).to receive_message_chain(:available_tools, :includes).and_return([real_tool_1])
          get :index
          expect(assigns[:tools]).to eq([real_tool_1])
        end
        it "should render the index page" do
          get :index
          expect(response).to render_template("index")
        end
      end

      describe "tool_config_select" do

        it "should render empty text if tool_id is empty" do
          get(:tool_config_select, params: {tool_id: ""})
          expect(response.body).to be_empty
        end

        it "should render bourreau_select if the tc is accessible by the use" do
          allow(normal_user).to receive_message_chain(:available_tools, :find).and_return(real_tool_1)
          get(:tool_config_select,params: {tool_id: real_tool_1.id.to_s})
          expect(response).to render_template("tools/_tool_config_select")
        end

        it "should display error text if go in rescue" do
          get(:tool_config_select, params: {tool_id: "abc"})
          expect(response.body).to match(/No Execution Servers/)
        end
      end

      describe "edit" do

        it "should redirect to error page" do
          get(:edit, params: {id: "1"})
          expect(response.code).to eq('401')
        end
      end

      describe "create" do

        it "should redirect to error page" do
          post(:create, params: {tool: {:name => "name"}})
          expect(response.code).to eq('401')
        end

      end

      describe "update" do

        it "should redirect to error page" do
          put :update, params: {id: "1"}
          expect(response.code).to eq('401')
        end
      end

      describe "destroy" do

        it "should redirect to error page" do
          delete :destroy, params: {id: "1"}
          expect(response.code).to eq('401')
        end
      end

    end

    context "user is a site_manager" do
      let(:site_manager_user) { create(:site_manager) }
      before(:each) do
        allow(site_manager_user).to receive(:license_agreement_set).and_return([])
        allow(controller).to receive(:current_user).and_return(site_manager_user)
        session[:session_id] = 'session_id'
      end

      describe "index" do

        it "should assign @tools with all tools avaible for this user" do
          allow(site_manager_user).to receive_message_chain(:available_tools, :includes).and_return([real_tool_1])
          get :index
          expect(assigns[:tools].to_a).to eq([real_tool_1])
        end
        it "should render the index page" do
          get :index
          expect(response).to render_template("index")
        end
      end

      describe "tool_config_select" do
        let(:real_tool) { create(:tool, :user_id => site_manager_user.id ) }

        it "should render empty text if tool_id is empty" do
          get(:tool_config_select, params: {tool_id:""})
          expect(response.body).to be_empty
        end

       it "should render bourreau_select if the tc is accessible by the use" do
          allow(site_manager_user).to receive_message_chain(:available_tools, :find).and_return(real_tool_1)
          get(:tool_config_select, params: {tool_id: real_tool_1.id.to_s})
          expect(response).to render_template("tools/_tool_config_select")
        end

        it "should display error text if go in rescue" do
          get(:tool_config_select, params: {tool_id: "abc"})
          expect(response.body).to match(/No Execution Servers/)
        end
      end

      describe "edit" do

        it "should redirect to error page" do
          get(:edit, params: {id: "1"})
          expect(response.code).to eq('401')
        end
      end

      describe "create" do

        it "should redirect to error page" do
          post(:create, params: {tool: {:name => "name"}})
          expect(response.code).to eq('401')
        end

      end

      describe "update" do

        it "should redirect to error page" do
          put :update, params: {id: "1" }
          expect(response.code).to eq('401')
        end
      end

      describe "destroy" do

        it "should redirect to error page" do
          delete :destroy, params: {id: "1"}
          expect(response.code).to eq('401')
        end
      end

    end
  end

  context "when the user is not logged in" do
    describe "index" do
      it "should redirect the login page" do
        get :index
        expect(response).to redirect_to(:controller => :sessions, :action => :new)
      end
    end

    describe "edit" do
      it "should redirect the login page" do
        get :edit,  params: {id: 1}
        expect(response).to redirect_to(:controller => :sessions, :action => :new)
      end
    end

    describe "create" do
      it "should redirect the login page" do
        post :create
        expect(response).to redirect_to(:controller => :sessions, :action => :new)
      end
    end

    describe "update" do
      it "should redirect the login page" do
        put :update, params: {id: 1}
        expect(response).to redirect_to(:controller => :sessions, :action => :new)
      end
    end

    describe "destroy" do
      it "should redirect the login page" do
        delete :destroy, params: {id: 1}
        expect(response).to redirect_to(:controller => :sessions, :action => :new)
      end
    end
  end
end

