
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

RSpec.describe UsersController, :type => :controller do
  let(:admin)        { create(:admin_user) }
  let(:site_manager) { create(:site_manager) }
  let(:site_user)    { create(:normal_user, :site => site_manager.site) }
  let(:user)         { create(:normal_user) }
  let(:mock_user)    { mock_model(User).as_null_object }

  let(:start_page_path) {controller.send :start_page_path}

  context "collection action" do

    describe "index" do
      before(:each) do
        1.upto(3) { |x| create(:normal_user, :city    => "city_#{rand(100)}",
                                             :country => "country_#{rand(100)}",
                              )
                  }
      end
      context "with admin user" do
        before(:each) do
          session[:user_id] = admin.id
        end
        it "should sort by full name by default" do
          get :index
          expect(assigns[:users]).to eq(User.order(:full_name).all)
        end
        it "should sort by full name" do
          get :index, "_scopes"=>{"users" => {"o"=>[{"a"=>"full_name"}]}}
          expect(assigns[:users]).to eq(User.order(:full_name).all)
        end
        it "should sort by last connection" do
          get :index, "_scopes"=>{"users" => {"o"=>[{"a"=>"last_connected_at"}]}}
          expect(assigns[:users]).to eq(User.order(:last_connected_at).all)
        end
        it "should sort by site" do
          get :index, "_scopes"=>{"users" => {"o" =>[{"a"=>"sites"}]}}
          expect(assigns[:users]).to eq(User.includes("site").order("sites.name").all)
        end
        it "should sort by city" do
          get :index, "_scopes"=>{"users" => {"o" =>[{"a"=>"city"}]}}
          expect(assigns[:users]).to eq(User.order(:city).all)
        end
        it "should sort by country" do
          get :index, "_scopes"=>{"users" => {"o" =>[{"a"=>"country"}]}}
          expect(assigns[:users]).to eq(User.order(:country).all)
        end
      end
      context "with site manager" do
        before(:each) do
          session[:user_id] = site_manager.id
          1.upto(3) {  create(:normal_user, :site => site_manager.site) }
        end
        it "should only show users from site" do
          get :index
          expect(assigns[:users].sort_by(&:id)).to match(User.where(:site_id => site_manager.site_id).order(:id).all)
        end
      end
      context "with regular user" do
        before(:each) do
          session[:user_id] = user.id
        end
        it "should return a 401 (unauthorized)" do
          get :index
          expect(response.response_code).to eq(401)
        end
      end
    end

    describe "create" do
      before(:each) do
        allow(CbrainMailer).to receive(:registration_confirmation)
      end

      context "with admin user" do
        before(:each) do
          session[:user_id] = admin.id
        end

        it "should allow the login to be set" do
          post :create, :user => {:login => "login"}
          expect(assigns[:user].login).to eq("login")
        end

        it "should allow type to be set to admin" do
          post :create, :user => {:type => "AdminUser"}
          expect(assigns[:user].type).to eq("AdminUser")
        end

        it "should allow type to be set to site manager" do
          post :create, :user => {:type => "SiteManager"}
          expect(assigns[:user].type).to eq("SiteManager")
        end

        it "should allow type to be set to user" do
          post :create, :user => {:type => "NormalUser"}
          expect(assigns[:user].type).to eq("NormalUser")
        end

        it "should allow the site to be set" do
          post :create, :user => {:site_id => user.site_id}
          expect(assigns[:user].site_id).to eq(user.site_id)
        end

        context "when save is successful" do
          before(:each) do
            allow(User).to receive(:new).and_return(mock_user)
            allow(mock_user).to receive_message_chain(:errors, :empty?).and_return(true)
          end

          it "should send a confirmation email if email is valid" do
            allow(mock_user).to receive(:email).and_return("me@here.com")
            expect(CbrainMailer).to receive(:registration_confirmation)
            post :create, :user => {}
          end

          it "should not send a confirmation email if email is invalid" do
            allow(mock_user).to receive(:email).and_return("invalid_email")
            expect(CbrainMailer).not_to receive(:registration_confirmation)
            post :create, :user => {}
          end

        end

        context "when save failed" do

          it "should render partial failed_create" do
            allow(User).to receive(:new).and_return(mock_user)
            allow(mock_user).to receive(:save).and_return(false)
            post :create, :user => {}, :format => :js
            expect(response.status).to eq(406)
          end

        end
      end

      context "with site manager" do
        before(:each) do
          session[:user_id] = site_manager.id
        end

        it "should allow the login to be set" do
          post :create, :user => {:login => "login"}
          expect(assigns[:user].login).to eq("login")
        end

        it "should not allow type to be set to admin" do
          post :create, :user => {:type => "AdminUser"}
          expect(assigns[:user].type).not_to eq("AdminUser")
        end

        it "should allow type to be set to site manager" do
          post :create, :user => {:type => "SiteManager"}
          expect(assigns[:user].type).to eq("SiteManager")
        end

        it "should allow type to be set to user" do
          post :create, :user => {:type => "NormalUser"}
          expect(assigns[:user].type).to eq("NormalUser")
        end

        it "should automatically set site to manager's site'" do
          post :create, :user => {:site_id => user.site_id}
          expect(assigns[:user].site_id).to eq(site_manager.site_id)
        end

      end

      context "with standard user" do
        before(:each) do
          session[:user_id] = user.id
        end

        it "should return a 401 (unauthorized)" do
          post :create
          expect(response.response_code).to eq(401)
        end

      end
    end

    describe "send_password" do
      before(:each) do
        allow(CbrainMailer).to receive_message_chain(:forgotten_password, :deliver)
      end

      context "when user is found" do

        it "should set the users 'password reset' flag" do
          post :send_password, :login => user.login, :email => user.email
          expect(assigns[:user].password_reset).to be_truthy
        end

        it "should change the password" do
          post :send_password, :login => user.login, :email => user.email
          expect(assigns[:user].password).not_to eq(user.password)
        end

        context "when the account is locked" do

          it "should display a message" do
            allow(mock_user).to receive(:account_locked?).and_return(true)
            allow(User).to receive_message_chain(:where, :first).and_return(mock_user)
            post :send_password, :login => user.login, :email => user.email
            expect(flash[:error]).to match(/locked/i)
          end

        end

        context "when reset is succesful" do

          it "should send an e-mail" do
            expect(CbrainMailer).to receive(:forgotten_password)
            post :send_password, :login => user.login, :email => user.email
          end

        end

        context "when reset fails" do

          it "should display flash message about problem" do
            mock_user = mock_model(User, :save => false, :account_locked? => false).as_null_object
            allow(User).to receive_message_chain(:where, :first).and_return(mock_user)
            post :send_password
            expect(flash[:error]).to match(/^Unable to reset password/)
          end

        end
      end

      context "when user is not found" do
        before(:each) do
          allow(User).to receive_message_chain(:where, :first).and_return(nil)
        end

        it "should display flash message about problem" do
          post :send_password
          expect(flash[:error]).to match(/^Unable to find user/)
        end

      end
    end

    describe "new" do
      context "with admin" do
        before(:each) do
          session[:user_id] = admin.id
        end

        it "should render new" do
          get :new
          expect(response).to render_template("new")
        end
      end

      context "with site_manager" do
        before(:each) do
          session[:user_id] = site_manager.id
        end

        it "should render new" do
          get :new
          expect(response).to render_template("new")
        end

      end

      context "with standard user" do
        before(:each) do
          session[:user_id] = user.id
        end

        it "should return a 401 (unauthorized)" do
          get :new
          expect(response.code).to eq('401')
        end

      end
    end
  end

  context "member action" do

    describe "show" do
      let(:start_path) {controller.send(:start_page_path)}

      context "with admin user" do
        before(:each) do
          session[:user_id] = admin.id
        end

        it "should show any user" do
          get :show, :id => user.id
          expect(response).to render_template("show")
        end
      end

      context "with site manager" do
        before(:each) do
          session[:user_id] = site_manager.id
        end

        it "should show a user associated with the site" do
          get :show, :id => site_user.id
          expect(response).to render_template("show")
        end

        it "should not show a user not associated with the site" do
          get :show, :id => user.id
          expect(response).to redirect_to(start_path)
        end

      end

      context "with regular user" do
        before(:each) do
          session[:user_id] = user.id
        end

        it "should show self" do
          get :show, :id => user.id
          expect(response).to render_template("show")
        end

        it "should not show other users" do
          get :show, :id => site_user.id
          expect(response).to redirect_to(start_path)
        end

      end
    end

    describe "change_password" do
      context "with admin user" do
        before(:each) do
          session[:user_id] = admin.id
        end
        it "should show the change password page" do
          get :change_password, :id => user.id
          expect(response.status).to eq(200)
        end
      end
      context "with site manager" do
        before(:each) do
          session[:user_id] = site_manager.id
        end
        it "should show the change password page if the user belongs to the site" do
          get :change_password, :id => site_user.id
          expect(response.status).to eq(200)
        end
        it "should not show the change password page if the user does not belong to the site" do
          get :change_password, :id => user.id
          expect(response).to redirect_to(start_page_path)
        end
      end
      context "with normal user" do
        before(:each) do
          session[:user_id] = user.id
        end
        it "should allow a user to change their own password" do
          get :change_password, :id => user.id
          expect(response.status).to eq(200)
        end
        it "should not allow the user to change anyone else's password'" do
          get :change_password, :id => site_user.id
          expect(response).to redirect_to(start_page_path)
        end
      end
    end

    describe "update" do
      context "with admin user" do
        before(:each) do
          session[:user_id] = admin.id
        end

        it "should allow type to be set to admin" do
          put :update, :id => user.id, :user => {:type => "AdminUser"}
          expect(assigns[:user].type).to eq("AdminUser")
        end

        it "should allow type to be set to site manager" do
          put :update, :id => user.id, :user => {:type => "SiteManager", :site_id => site_manager.site.id}
          expect(assigns[:user].type).to eq("SiteManager")
        end

        it "should allow type to be set to user" do
          put :update, :id => user.id, :user => {:type => "NormalUser"}
          expect(assigns[:user].type).to eq("NormalUser")
        end

        it "should allow the site to be set" do
          put :update, :id => user.id, :user => {:site_id => user.site_id}
          expect(assigns[:user].site_id).to eq(user.site_id)
        end

        it "should allow me to add groups" do
          new_group =  create(:work_group)
          put :update, :id => user.id, :user => {:group_ids => [new_group.id]}
          user.reload
          expect(user.group_ids).to include(new_group.id)
        end

        it "should allow me to reset groups" do
          new_group =  create(:work_group, :user_ids => [user.id])
          put :update, :id => user.id, :user => {:group_ids => []}
          user.reload
          expect(user.group_ids).not_to include(new_group.id)
        end

        it "should add meta data if any was sent" do
          expect(controller).to receive(:add_meta_data_from_form)
          put :update, :id => user.id, :meta => {:key => :value}
        end

      end

      context "with site manager" do
        before(:each) do
          session[:user_id] = site_manager.id
        end

        it "should not allow site manager to modify a user that does not belong to the site" do
          put :update, :id => user.id
          expect(response).to redirect_to(start_page_path)
        end

        it "should not allow type to be set to admin" do
          put :update, :id => site_user.id, :user => {:type => "AdminUser"}
          expect(assigns[:user].type).not_to eq("AdminUser")
        end

        it "should allow type to be set to site manager" do
          put :update, :id => site_user.id, :user => {:type => "SiteManager"}
          expect(assigns[:user].type).to eq("SiteManager")
        end

        it "should allow type to be set to user" do
          put :update, :id => site_user.id, :user => {:type => "NormalUser"}
          expect(assigns[:user].type).to eq("NormalUser")
        end

        it "should automatically set site to manager's site'" do
          put :update, :id => site_user.id, :user => {:site_id => user.site_id}
          expect(assigns[:user].site_id).to eq(site_user.site_id)
        end

        it "should allow site manager to add groups" do
          new_group =  create(:work_group)
          put :update, :id => site_user.id, :user => {:group_ids => [new_group.id]}
          site_user.reload
          expect(site_user.group_ids).to include(new_group.id)
        end

        it "should allow site manager to reset groups" do
          new_group =  create(:work_group, :user_ids => [site_user.id])
          put :update, :id => site_user.id, :user => {:group_ids => []}
          site_user.reload
          expect(site_user.group_ids).not_to include(new_group.id)
        end

      end

      context "with regular user" do
        before(:each) do
          session[:user_id] = user.id
        end

        it "should not allow another user to be modified" do
          put :update, :id => site_user.id
          expect(response).to redirect_to(start_page_path)
        end

        it "should not allow type to be modified" do
          put :update, :id => user.id, :user => {:type => "SiteManager"}
          expect(assigns[:user].type).to eq(user.type)
        end

        it "should not allow site to be modified" do
          put :update, :id => user.id, :user => {:site_id => site_user.site_id}
          expect(assigns[:user].site_id).to eq(user.site_id)
        end

        it "should not allow groups to be modified" do
          new_group =  create(:work_group)
          put :update, :id => user.id, :user => {:group_ids => [new_group.id]}
          user.reload
          expect(user.group_ids).not_to include(new_group.id)
        end

      end

      context "when the update fails" do
        before(:each) do
          session[:user_id] = admin.id
          allow(User).to receive(:find).and_return(double("updated_user", :save_with_logging => false).as_null_object)
        end

        it "should redirect to change_password if password change was attempted" do
          put :update, :id => user.id, :user => {:password => "password"}
          expect(response).to render_template(:change_password)
        end
        it "should redirect to show otherwise" do
          put :update, :id => user.id, :user => {:full_name => "NAME"}
          expect(response).to render_template(:show)
        end
      end

    end

    describe "destroy" do
      context "with admin user" do
        before(:each) do
          session[:user_id] = admin.id
        end

        it "should allow admin to destroy a user" do
          delete :destroy, :id => user.id
          expect(User.all).not_to include(user)
        end

        it "should redirect to the index" do
          delete :destroy, :id => user.id, :format => "js"
          expect(response).to redirect_to(:action => :index, :format => :js)
        end

      end

      context "with site manager" do
        before(:each) do
          session[:user_id] = site_manager.id
        end

        it "should allow site manager to destroy a user from the site" do
          delete :destroy, :id => site_user.id
          expect(User.all).not_to include(user)
        end

        it "should not allow site manager to destroy a user not from the site" do
          expect { delete :destroy, :id => user.id }.to raise_error(ActiveRecord::RecordNotFound)
        end

      end

      context "with regular user" do
        before(:each) do
          session[:user_id] = user.id
        end

        it "should return a 401 (unauthorized)" do
          post :create
          expect(response.response_code).to eq(401)
        end

      end
    end

    describe "switch" do
       let(:current_session) do
         h = CbrainSession.new(session, ActiveRecord::SessionStore::Session.new )
         allow(h).to receive(:params_for).and_return({})
         h
       end

      before(:each) do
        allow(controller).to receive(:current_session).and_return(current_session)
      end

      context "with admin user" do
        before(:each) do
          session[:user_id] = admin.id
        end

        it "should switch the current user" do
          post :switch, :id => user.id
          expect(current_session[:user_id]).to eq(user.id)
        end

        it "should redirect to the welcome page" do
          post :switch, :id => user.id
          expect(response).to redirect_to("/groups")
        end
      end

      context "with site manager" do
        before(:each) do
          session[:user_id] = site_manager.id
        end

        it "should allow switching to a user from the site" do
          post :switch, :id => site_user.id
          expect(current_session[:user_id]).to eq(site_user.id)
        end

        it "should not allow switching to a user not from the site" do
          expect { post :switch, :id => user.id }.to raise_error(ActiveRecord::RecordNotFound)
          expect(current_session[:user_id]).not_to eq(user.id)
        end
      end

      context "with regular user" do
        before(:each) do
          session[:user_id] = user.id
        end

        it "should return a 401 (unauthorized)" do
          post :create
          expect(response.response_code).to eq(401)
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

    describe "show" do

      it "should redirect the login page" do
        get :show, :id => 1
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
        put :update, :id => 1
        expect(response).to redirect_to(:controller => :sessions, :action => :new)
      end

    end

    describe "destroy" do

      it "should redirect the login page" do
        delete :destroy, :id => 1
        expect(response).to redirect_to(:controller => :sessions, :action => :new)
      end

    end

    describe "switch" do

      it "should redirect the login page" do
        post :switch, :id => 1
        expect(response).to redirect_to(:controller => :sessions, :action => :new)
      end

    end
  end

end

