
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

  fake_user = FactoryBot.attributes_for(:user)


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
          session[:session_id] = 'session_id'
        end
        it "should sort by full name by default" do
          get :index
          expect(assigns[:users]).to eq(User.order(:full_name).all.to_a)
        end
        it "should sort by full name" do
          get :index, params: {"_scopes"=>{"users#index" => {"o"=>[{"a"=>"full_name"}]}}}
          expect(assigns[:users]).to eq(User.order(:full_name).all.to_a)
        end
        it "should sort by last connection" do
          get :index, params: {"_scopes"=>{"users#index" => {"o"=>[{"a"=>"last_connected_at"}]}}}
          expect(assigns[:users]).to eq(User.order(:last_connected_at).all.to_a)
        end
        it "should sort by site" do
          get :index, params: {"_scopes"=>{"users#index" => {"o" =>[{"a"=>"sites"}]}}}
          expect(assigns[:users]).to eq(User.includes("site").order("sites.name").all.to_a)
        end
        it "should sort by city" do
          get :index, params: {"_scopes"=>{"users#index" => {"o" =>[{"a"=>"city"}]}}}
          expect(assigns[:users]).to eq(User.order(:city).all.to_a)
        end
        it "should sort by country" do
          get :index, params: {"_scopes"=>{"users#index" => {"o" =>[{"a"=>"country"}]}}}
          expect(assigns[:users]).to eq(User.order(:country).all.to_a)
        end
      end
      context "with site manager" do
        before(:each) do
          session[:user_id] = site_manager.id
          session[:session_id] = 'session_id'
          1.upto(3) {  create(:normal_user, :site => site_manager.site) }
        end
        it "should only show users from site" do
          get :index
          expect(assigns[:users].sort_by(&:id)).to match(User.where(:site_id => site_manager.site_id).order(:id).all)
        end
      end
      context "with regular user" do
        before(:each) do
          session[:user_id]    = user.id
          session[:session_id] = 'session_id'
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
          session[:user_id]    = admin.id
          session[:session_id] = 'session_id'
        end

        it "should allow the login to be set" do
          post :create, params: {:user => {:login => "login"}}
          expect(assigns[:user].login).to eq("login")
        end

        it "should allow type to be set to admin" do
          post :create, params: {:user => {:type => "AdminUser"}}
          expect(assigns[:user].type).to eq("AdminUser")
        end

        it "should allow type to be set to site manager" do
          post :create, params: {:user => {:type => "SiteManager"}}
          expect(assigns[:user].type).to eq("SiteManager")
        end

        it "should allow type to be set to user" do
          post :create, params: {:user => {:type => "NormalUser"}}
          expect(assigns[:user].type).to eq("NormalUser")
        end

        it "should allow the site to be set" do
          post :create, params: {:user => {:site_id => user.site_id}}
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
            post :create, params: {:user => fake_user}
          end

          it "should not send a confirmation email if email is invalid" do
            allow(mock_user).to receive(:email).and_return("invalid_email")
            expect(CbrainMailer).not_to receive(:registration_confirmation)
            post :create, params: {:user => fake_user}
          end

        end

        context "when save failed" do

          it "should return unprocessable entity" do
            allow(User).to receive(:new).and_return(user)
            allow(user).to receive(:save).and_return(false)
            post :create, params: {:user => {id: user.id}}, format: :json
            expect(response.status).to eq(422)
          end

        end
      end

      context "with site manager" do
        before(:each) do
          session[:user_id] = site_manager.id
          session[:session_id] = 'session_id'
        end

        it "should allow the login to be set" do
          post :create, params: {:user => {:login => "login"}}
          expect(assigns[:user].login).to eq("login")
        end

        it "should not allow type to be set to admin" do
          post :create, params: {:user => {:type => "AdminUser"}}
          expect(assigns[:user].type).not_to eq("AdminUser")
        end

        it "should allow type to be set to site manager" do
          post :create, params: {:user => {:type => "SiteManager"}}
          expect(assigns[:user].type).to eq("SiteManager")
        end

        it "should allow type to be set to user" do
          post :create, params: {:user => {:type => "NormalUser"}}
          expect(assigns[:user].type).to eq("NormalUser")
        end

        it "should automatically set site to manager's site'" do
          post :create, params: {:user => {:site_id => user.site_id}}
          expect(assigns[:user].site_id).to eq(site_manager.site_id)
        end

      end

      context "with standard user" do
        before(:each) do
          session[:user_id]    = user.id
          session[:session_id] = 'session_id'
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
          post :send_password, params: {:login => user.login, :email => user.email}
          expect(assigns[:user].password_reset).to be_truthy
        end

        it "should change the password" do
          post :send_password, params: {:login => user.login, :email => user.email}
          expect(assigns[:user].password).not_to eq(user.password)
        end

        context "when the account must use Globus identification only" do

          it "should display a message" do
            allow(mock_user).to receive(:account_locked?).and_return(true)
            allow(User).to receive_message_chain(:where, :first).and_return(mock_user)
            post :send_password, params: {:login => user.login, :email => user.email}
            expect(flash[:error]).to match(/Globus/i)
          end

        end

        context "when the account is locked" do

          it "should display a message" do
            allow(mock_user).to receive(:account_locked?).and_return(true)
            allow(mock_user).to receive(:meta).and_return({ "allowed_globus_provider_names" => "" })
            allow(User).to receive_message_chain(:where, :first).and_return(mock_user)
            post :send_password, params: {:login => user.login, :email => user.email}
            expect(flash[:error]).to match(/locked/i)
          end

        end

        context "when reset is successful" do

          it "should send an e-mail" do
            expect(CbrainMailer).to receive(:forgotten_password)
            post :send_password, params: {:login => user.login, :email => user.email}
          end

        end

        context "when reset fails" do

          it "should display flash message about problem" do
            mock_user = mock_model(User,
                                   :save => false,
                                   :account_locked? => false,
                                   :meta => { "allowed_globus_provider_names" => "" }
            ).as_null_object
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
          session[:session_id] = 'session_id'
        end

        it "should render new" do
          get :new
          expect(response).to render_template("new")
        end
      end

      context "with site_manager" do
        before(:each) do
          session[:user_id]    = site_manager.id
          session[:session_id] = 'session_id'
        end

        it "should render new" do
          get :new
          expect(response).to render_template("new")
        end

      end

      context "with standard user" do
        before(:each) do
          session[:user_id] = user.id
          session[:session_id] = 'session_id'
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
          session[:session_id] = 'session_id'
        end

        it "should show any user" do
          get :show, params: {:id => user.id}
          expect(response).to render_template("show")
        end
      end

      context "with site manager" do
        before(:each) do
          session[:user_id] = site_manager.id
          session[:session_id] = 'session_id'
        end

        it "should show a user associated with the site" do
          get :show, params: {:id => site_user.id}
          expect(response).to render_template("show")
        end

        it "should not show a user not associated with the site" do
          get :show, params: {:id => user.id}
          expect(response).to redirect_to(start_path)
        end

      end

      context "with regular user" do
        before(:each) do
          session[:user_id] = user.id
          session[:session_id] = 'session_id'
        end

        it "should show self" do
          get :show, params: {:id => user.id}
          expect(response).to render_template("show")
        end

        it "should not show other users" do
          get :show, params: {:id => site_user.id}
          expect(response).to redirect_to(start_path)
        end

      end
    end

    describe "change_password" do
      context "with admin user" do
        before(:each) do
          session[:user_id] = admin.id
          session[:session_id] = 'session_id'
        end
        it "should show the change password page" do
          get :change_password, params: {:id => user.id}
          expect(response.status).to eq(200)
        end
      end
      context "with site manager" do
        before(:each) do
          session[:user_id] = site_manager.id
          session[:session_id] = 'session_id'
        end
        it "should show the change password page if the user belongs to the site" do
          get :change_password, params: {:id => site_user.id}
          expect(response.status).to eq(200)
        end
        it "should not show the change password page if the user does not belong to the site" do
          get :change_password, params: {:id => user.id}
          expect(response).to redirect_to(start_page_path)
        end
      end
      context "with normal user" do
        before(:each) do
          session[:user_id] = user.id
          session[:session_id] = 'session_id'
        end
        it "should allow a user to change their own password" do
          get :change_password, params: {:id => user.id}
          expect(response.status).to eq(200)
        end
        it "should not allow the user to change anyone else's password'" do
          get :change_password, params: {:id => site_user.id}
          expect(response).to redirect_to(start_page_path)
        end
      end
    end

    describe "update" do
      context "with admin user" do
        before(:each) do
          session[:user_id] = admin.id
          session[:session_id] = 'session_id'
        end

        it "should allow type to be set to admin" do
          put :update, params: {:id => user.id, :user => {:type => "AdminUser"}}
          expect(assigns[:user].type).to eq("AdminUser")
        end

        it "should allow type to be set to site manager" do
          put :update, params: {:id => user.id, :user => {:type => "SiteManager", :site_id => site_manager.site.id}}
          expect(assigns[:user].type).to eq("SiteManager")
        end

        it "should allow type to be set to user" do
          put :update, params: {:id => user.id, :user => {:type => "NormalUser"}}
          expect(assigns[:user].type).to eq("NormalUser")
        end

        it "should allow the site to be set" do
          put :update, params: {:id => user.id, :user => {:site_id => user.site_id}}
          expect(assigns[:user].site_id).to eq(user.site_id)
        end

        it "should allow me to add groups" do
          new_group =  create(:work_group)
          put :update, params: {:id => user.id, :user => {:group_ids => [new_group.id]}}
          user.reload
          expect(user.group_ids).to include(new_group.id)
        end

        it "should allow me to reset groups" do
          new_group =  create(:work_group, :user_ids => [user.id])
          fake_user[:group_ids] = [""]
          put :update, params: {:id => user.id, :user => fake_user  }
          user.reload
          expect(user.group_ids).not_to include(new_group.id)
        end

        it "should add meta data if any was sent" do
          expect(controller).to receive(:add_meta_data_from_form)
          put :update, params: {:id => user.id, :user => { :full_name => 'xyz' }, :meta => {:key => :value}}
        end

      end

      context "with site manager" do
        before(:each) do
          session[:user_id] = site_manager.id
          session[:session_id] = 'session_id'
        end

        it "should not allow site manager to modify a user that does not belong to the site" do
          put :update, params: {:id => user.id}
          expect(response).to redirect_to(start_page_path)
        end

        it "should not allow type to be set to admin" do
          put :update, params: {:id => site_user.id, :user => {:type => "AdminUser"}}
          expect(assigns[:user].type).not_to eq("AdminUser")
        end

        it "should allow type to be set to site manager" do
          put :update, params: {:id => site_user.id, :user => {:type => "SiteManager"}}
          expect(assigns[:user].type).to eq("SiteManager")
        end

        it "should allow type to be set to user" do
          put :update, params: {:id => site_user.id, :user => {:type => "NormalUser"}}
          expect(assigns[:user].type).to eq("NormalUser")
        end

        it "should automatically set site to manager's site'" do
          put :update, params: {:id => site_user.id, :user => {:site_id => user.site_id}}
          expect(assigns[:user].site_id).to eq(site_user.site_id)
        end

        it "should allow site manager to add groups" do
          new_group =  create(:work_group)
          put :update, params: {:id => site_user.id, :user => {:group_ids => [new_group.id]}}
          site_user.reload
          expect(site_user.group_ids).to include(new_group.id)
        end

        it "should allow site manager to reset groups" do
          new_group =  create(:work_group, :user_ids => [site_user.id])
          fake_user[:group_ids] = [""]
          put :update, params: {:id => site_user.id, :user => fake_user}
          site_user.reload
          expect(site_user.group_ids).not_to include(new_group.id)
        end

      end

      context "with regular user" do
        before(:each) do
          session[:user_id] = user.id
          session[:session_id] = 'session_id'
        end

        it "should not allow another user to be modified" do
          put :update, params: {:id => site_user.id}
          expect(response).to redirect_to(start_page_path)
        end

        it "should not allow type to be modified" do
          put :update, params: {:id => user.id, :user => {:type => "SiteManager"}}
          expect(assigns[:user].type).to eq(user.type)
        end

        it "should not allow site to be modified" do
          put :update, params: {:id => user.id, :user => {:site_id => site_user.site_id}}
          expect(assigns[:user].site_id).to eq(user.site_id)
        end

        it "should not allow groups to be modified" do
          new_group =  create(:work_group)
          put :update, params: {:id => user.id, :user => {:group_ids => [new_group.id]}}
          user.reload
          expect(user.group_ids).not_to include(new_group.id)
        end

      end

      context "when the update fails" do
        before(:each) do
          session[:user_id]    = admin.id
          session[:session_id] = 'session_id'
          allow(user).to receive(:save_with_logging).and_return(false)
        end

        it "should redirect to change_password if password change was attempted" do
          put :update, params: {:id => user.id, :user => {:password => "password"}}
          expect(response).to render_template(:change_password)
        end
        it "should render show page otherwise" do
          put :update, params: {:id => user.id, :user => {:login => "immutable" }}
          expect(response).to render_template(:show)
        end
      end

    end

    describe "destroy" do
      context "with admin user" do
        before(:each) do
          session[:user_id]    = admin.id
          session[:session_id] = 'session_id'
        end

        it "should allow admin to destroy a user" do
          delete :destroy, params: {:id => user.id}
          expect(User.all).not_to include(user)
        end

        it "should redirect to the index" do
          delete :destroy, params: {:id => user.id}, :format => "js"
          expect(response).to redirect_to(:action => :index, :format => :js)
        end

      end

      context "with site manager" do
        before(:each) do
          session[:user_id] = site_manager.id
          session[:session_id] = 'session_id'
        end

        it "should allow site manager to destroy a user from the site" do
          delete :destroy, params: {:id => site_user.id}
          expect(User.all.to_a).not_to include(user)
        end

        it "should not allow site manager to destroy a user not from the site" do
          delete :destroy, params: {:id => user.id }
          expect(flash['error']).to eq(ExceptionHelpers::NOT_FOUND_MSG)
        end

      end

      context "with regular user" do
        before(:each) do
          session[:user_id] = user.id
          session[:session_id] = 'session_id'
        end

        it "should return a 401 (unauthorized)" do
          post :create
          expect(response.response_code).to eq(401)
        end

      end
    end

    describe "switch" do
      # NOTE: the mock model below is not right.... :-( cbrain_sesssion() returns a CbrainSession object!
      let(:cbrain_session) { mock_model(LargeSessionInfo, "guessed_remote_ip" => '0.0.0.0', "_csrf_token" => 'dummy csrf', "session_id" => 'session_id', "user_id" => admin.id).as_null_object }

      before(:each) do
        allow(controller).to receive(:cbrain_session).and_return(cbrain_session)
      end

      context "with admin user" do
        before(:each) do
          session[:user_id]    = admin.id
          session[:session_id] = 'session_id'
        end

        it "should switch the current user" do
          expect(cbrain_session).to receive(:clear)
          expect(cbrain_session).to receive(:user_id=).with(user.id)
          post :switch, params: {:id => user.id}
        end

        it "should redirect to the welcome page" do
          session[:session_id] = 'session_id'
          post :switch, params: {:id => user.id}
          expect(response).to redirect_to("/groups")
        end
      end

      context "with site manager" do
        before(:each) do
          session[:user_id]    = site_manager.id
          session[:session_id] = 'session_id'
        end

        it "should allow switching to a user from the site" do
          expect(cbrain_session).to receive(:clear)
          expect(cbrain_session).to receive(:user_id=).with(site_user.id)
          post :switch, params: {:id => site_user.id}
        end

        it "should not allow switching to a user not from the site" do
          post :switch, params: {:id => user.id }
          expect(flash[:error]).to eq(ExceptionHelpers::NOT_FOUND_MSG)
          expect(cbrain_session[:user_id]).not_to eq(user.id)
        end
      end

      context "with regular user" do
        before(:each) do
          session[:user_id] = user.id
          session[:session_id] = 'session_id'
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
        get :show, params: {:id => 1}
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
        put :update, params: {:id => 1}
        expect(response).to redirect_to(:controller => :sessions, :action => :new)
      end

    end

    describe "destroy" do

      it "should redirect the login page" do
        delete :destroy, params: {:id => 1}
        expect(response).to redirect_to(:controller => :sessions, :action => :new)
      end

    end

    describe "switch" do

      it "should redirect the login page" do
        post :switch, params: {:id => 1}
        expect(response).to redirect_to(:controller => :sessions, :action => :new)
      end

    end
  end

end

