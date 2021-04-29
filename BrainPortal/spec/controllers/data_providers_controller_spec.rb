
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

RSpec.describe DataProvidersController, :type => :controller do
  let(:data_provider) { mock_model(DataProvider).as_null_object }
  let(:admin_user)    { create(:admin_user) }
  let(:scratch_dp)    { ScratchDataProvider.main }

  context "with an admin user" do
    before(:each) do
      allow(controller).to receive(:current_user).and_return(admin_user)
      allow(admin_user).to receive(:license_agreement_set).and_return([])
      allow(admin_user).to receive(:unsigned_license_agreements).and_return([])
      session[:user_id]    = admin_user.id
      session[:session_id] = 'session_id'
    end

    context "collection action" do
      describe "index" do
        let!(:local_dp) { create(:flat_dir_local_data_provider) }
        it "should assign @data_providers" do
          get :index
          # BTW: fails if the rake task 'db:sanity:check' was not run
          expect(assigns[:data_providers].to_a).to match_array([scratch_dp,local_dp])
        end
        it "should render the index page" do
         get :index
         expect(response).to render_template("index")
        end
      end
      describe "new" do
        it "should create a new data provider" do
          expect(DataProvider).to receive(:new)
          get :new
        end
        it "should get the type list" do
          expect(controller).to receive(:get_type_list)
          get :new
        end
        it "should render the new page" do
          get :new
          expect(response).to render_template(:new)
        end
      end
      describe "create" do
        before(:each) do
          allow(DataProvider).to receive(:sti_new).and_return(data_provider.as_new_record)
        end
        context "when save is successful" do
          before(:each) do
            allow(data_provider).to receive(:save).and_return(true)
            allow(data_provider).to receive_message_chain(:errors, :empty?).and_return(true)
          end
          it "should add the meta data" do
            expect(controller).to receive(:add_meta_data_from_form)
            post :create, :xhr => true
          end

          it "should display a flash message" do
            post :create, :xhr => true
            expect(flash[:notice]).to match("created")
          end

          it "should redirect to index" do
            post :create, :format => :html
            expect(response).to redirect_to(:action => :index, :format => :html)
          end
        end
        context "when save fails" do
          before(:each) do
            allow(data_provider).to receive(:save).and_return(false)
            allow(data_provider).to receive_message_chain(:errors, :empty?).and_return(false)
          end
          it "should not add the meta data" do
            expect(controller).not_to receive(:add_meta_data_from_form)
            post :create, :xhr => true
          end
          it "should render new page again" do
            post :create, :xhr => true
            expect(response).to render_template(:new)
          end
        end
      end

      describe "dp_access" do

      end
      describe "dp_transfers" do

      end
    end
    context "member action" do
      before(:each) do
        allow(DataProvider).to receive(:find).and_return(data_provider)
      end
      describe "show" do
        it "should raise an cb_notice if the provider is not accessible by the current user" do
          allow(data_provider).to receive(:can_be_accessed_by?).and_return(false)
          get :show, params: {id: 1}
          expect(response).to redirect_to(:action => :index)
        end
        it "should render the show page" do
          get :show, params: {id: 1}
          expect(response).to render_template("show")
        end
      end
      describe "update" do
        before(:each) do
          allow(data_provider).to receive(:has_owner_access?).and_return(true)
          allow(data_provider).to receive(:update_attributes_with_logging).and_return(true)
        end
        it "should check if user has owner access" do
          expect(data_provider).to receive(:has_owner_access?)
          put :update, params: {id: 1}
        end
        it "should update attributes" do
          expect(data_provider).to receive(:update_attributes_with_logging)
          put :update, params: {id: 1}
        end
        context "user does not have access" do
          before(:each) do
            allow(data_provider).to receive(:has_owner_access?).and_return(false)
          end
          it "should display an error message" do
            put :update, params: {id: 1}
            expect(flash[:error]).not_to be_blank
          end
          it "should redirect to show" do
            put :update, params: {id: 1}
            expect(response).to redirect_to(:action => :show)
          end
        end
        context "success" do
          it "should add meta data" do
            expect(controller).to receive(:add_meta_data_from_form)
            put :update, params: {id: 1}
          end
          it "should display success message" do
            put :update, params: {id: 1}
            expect(flash[:notice]).to match("success")
          end
          it "should redirect to index" do
            put :update, params: {id: 1}
            expect(response).to redirect_to(:action => :show)
          end
        end
        context "failure" do
          before(:each) do
            allow(data_provider).to receive(:update_attributes_with_logging).and_return(false)
          end
          it "should reload the data_provider" do
            expect(data_provider).to receive(:reload)
            put :update, params: {id: 1}
          end
          it "should redirect to index" do
            put :update, params: {id: 1}
            expect(response).to render_template(:show)
          end
        end
      end
      describe "destroy" do
        before(:each) do
          allow(DataProvider).to receive(:find_accessible_by_user).and_return(data_provider)
          allow(data_provider).to receive(:has_owner_access?).and_return(true)
        end
        it "should display an error if the user does not have owner access" do
          allow(data_provider).to receive(:has_owner_access?).and_return(false)
          delete :destroy, params: {id: 1}
          expect(flash[:error]).not_to be_blank
        end
        it "should destroy the data provider" do
          expect(data_provider).to receive(:destroy)
          delete :destroy, params: {id: 1}
        end
        it "should redirect to index" do
          delete :destroy, params: {id: 1}
          expect(response).to redirect_to(:action => :index)
        end
        context "provider not destroyed" do
          before(:each) do
            allow(data_provider).to receive(:destroy).and_raise(ActiveRecord::DeleteRestrictionError.new("Not Destroyed!!!"))
          end
          it "should display an error message" do
            delete :destroy, params: {id: 1}
            expect(flash[:error]).to match("Not Destroyed!!!")
          end
          it "should redirect to index" do
            delete :destroy, params: {id: 1}
            expect(response).to redirect_to(:action => :index)
          end
        end
      end

      describe "is_alive" do
        before(:each) do
          allow(DataProvider).to receive(:find_accessible_by_user).and_return(data_provider)
        end
        it "should check if the data provider is alive" do
          expect(data_provider).to receive(:is_alive_with_caching?)
          get :is_alive, params: {id: 1}
        end
        it "should return yes if provider is alive" do
          allow(data_provider).to receive(:is_alive_with_caching?).and_return(true)
          get :is_alive, params: {id: 1}
          expect(response.body).to match(/yes/i)
        end
        it "should return no if provider is not alive" do
          allow(data_provider).to receive(:is_alive_with_caching?).and_return(false)
          get :is_alive, params: {id: 1}
          expect(response.body).to match(/no/i)
        end
      end
      describe "browse" do
        let(:file1) { double("file_info1", :name => "hi").as_null_object }
        let(:file2) { double("file_info2", :name => "bye").as_null_object }
        let(:file_info_list) {[ file1, file2 ]}

        before(:each) do
          allow(DataProvider).to  receive(:find_accessible_by_user).and_return(data_provider)
          allow(data_provider).to receive(:is_browsable?).and_return(true)
          allow(data_provider).to receive(:online?).and_return(true)
          allow(data_provider).to receive(:provider_list_all).and_return(file_info_list)

          # bypassing caching
          allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache.lookup_store(:memory_store))
          allow_any_instance_of(ActiveSupport::Cache::MemoryStore).to receive(:exist?).and_return(false)
          allow_any_instance_of(ActiveSupport::Cache::MemoryStore).to receive(:write).and_return(true)
        end
        context "provider is not browsable" do
          before(:each) do
            allow(data_provider).to receive(:is_browsable?).and_return(false)
          end
          it "should display an error message" do
            get :browse, params: {id: 1}
            expect(flash[:error]).not_to be_blank
          end
          it "should redirect to index" do
            get :browse, params: {id: 1}
            expect(response).to redirect_to(:action => :index)
          end
        end
        context "provider is not online" do
          before(:each) do
            allow(data_provider).to receive(:online?).and_return(false)
          end
          it "should display an error message" do
            get :browse, params: {id: 1}
            expect(flash[:error]).not_to be_blank
          end
          it "should redirect to index" do
            get :browse, params: {id: 1}
            expect(response).to redirect_to(:action => :index)
          end
        end
        it "should retrieve the list of files" do
          expect(BrowseProviderFileCaching).to receive(:get_recent_provider_list_all).and_return(file_info_list)
          get :browse, params: {id: 1}
        end
        it "should iterate over the file list" do
          allow(BrowseProviderFileCaching).to  receive(:get_recent_provider_list_all).and_return(file_info_list)
          expect(file_info_list).to receive(:each).at_least(2)
          get :browse, params: {id: 1}
        end
        it "should match remote files to registered files" do
          expect(FileInfo).to receive(:array_match_all_userfiles)
          get :browse, params: {id: 1}
        end
        it "should check that the filenames are legal" do
          expect(FileInfo).to receive(:array_validate_for_registration)
          get :browse, params: {id: 1}
        end
        it "should retrieve the list of file with name_like 'hi'" do
          get :browse, params: {id: 1, name_like: "hi", update_filter: :browse_hash}
          expect(assigns(:files)).to eq([file1])
        end
        it "should paginate the list" do
          expect(WillPaginate::Collection).to receive(:create)
          get :browse, params: {id: 1}
        end
        it "should render the browse page" do
          get :browse, params: {id: 1}
          expect(response).to render_template("browse")
        end
      end
      describe "register" do
        let(:registered_file) {mock_model(SingleFile, :save => true).as_null_object.as_new_record}

        before(:each) do
          allow(DataProvider).to receive(:find_accessible_by_user).and_return(data_provider)
          allow(data_provider).to receive(:is_browsable?).and_return(true)
          allow(CBRAIN).to receive(:spawn_with_active_records)
          allow(SingleFile).to receive(:new).and_return(registered_file)
          allow(registered_file).to receive(:save).and_return(true)
        end

        it "should check if the data_provider is browsable" do
          expect(data_provider).to receive(:is_browsable?)
          post :register, params: {id: 1, basenames: ["a_file"]}
        end

        context "provider is not browsable" do
          before(:each) do
            allow(data_provider).to receive(:is_browsable?).and_return(false)
          end
          it "should display an error message" do
            post :register, params: {id: 1, basenames: ["a_file"]}
            expect(flash[:error]).not_to be_blank
          end
          it "should redirect to index" do
            post :register, params: {id: 1, basenames: ["a_file"]}
            expect(response).to redirect_to(:action => :index)
          end
        end

        context "register only" do
          it "should set the sizes in a separate process" do
            expect(CBRAIN).to receive(:spawn_with_active_records)
            post :register, params: {id: 1, basenames: ["a_file"]}
          end
          it "should display that registration was a success" do
            post :register, params: {id: 1, basenames: ["a_file"]}
            expect(flash[:notice]).to match(/\bRegistering\b/i)
          end
          it "should redirect to browse" do
            post :register, params: {id: 1, basenames: ["a_file"]}
            expect(response).to redirect_to(:action => :browse)
          end
        end
        context "doing move or copy" do
          before(:each) do
            allow(CBRAIN).to receive(:spawn_with_active_records).and_yield
          end

          it "should check for collisions" do
            expect(Userfile).to receive(:where).and_return(double("registered files").as_null_object)
            post :register, params: {id: 1, basenames: ["a_file"],auto_do: "MOVE"}
          end
          it "should spawn a background process for moving" do
            expect(CBRAIN).to receive(:spawn_with_active_records)
            post :register, params: {id: 1, basenames: ["a_file"],auto_do: "MOVE"}
          end
          it "should redirect to browse" do
            post :register, params: {id: 1, basenames: ["a_file"],auto_do: "MOVE"}
            expect(response).to redirect_to(:action => :browse)
          end
          it "should move the file if a move is requested" do
            allow(controller).to receive(:userfiles_from_basenames).and_return({"b_file" => nil})
            expect(registered_file).to receive(:provider_move_to_otherprovider)
            post :register, params: {id: 1, basenames: ["b_file"], auto_do: "MOVE"}
          end
          it "should copy the file if a copy is requested" do
            allow(controller).to receive(:userfiles_from_basenames).and_return({"b_file" => nil})
            expect(registered_file).to receive(:provider_copy_to_otherprovider)
            post :register, params: {id: 1, basenames: ["b_file"], auto_do: "COPY"}
          end
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
    describe "new" do
      it "should redirect the login page" do
        get :new
        expect(response).to redirect_to(:controller => :sessions, :action => :new)
      end
    end
    describe "show" do
      it "should redirect the login page" do
        get :show, params: {id: 1}
        expect(response).to redirect_to(:controller => :sessions, :action => :new)
      end
    end
    describe "create" do
      it "should redirect the login page" do
        post :create
        expect(response).to redirect_to(:controller => :sessions, :action => :new)
      end
    end
    describe "dp_access" do
      it "should redirect the login page" do
        post :dp_access
        expect(response).to redirect_to(:controller => :sessions, :action => :new)
      end
    end
    describe "create" do
      it "should redirect the login page" do
        post :dp_transfers
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
    describe "is_alive" do
      it "should redirect the login page" do
        delete :is_alive, params: {id: 1}
        expect(response).to redirect_to(:controller => :sessions, :action => :new)
      end
    end
    describe "browse" do
      it "should redirect the login page" do
        delete :browse, params: {id: 1}
        expect(response).to redirect_to(:controller => :sessions, :action => :new)
      end
    end
    describe "register" do
      it "should redirect the login page" do
        delete :register, params: {id: 1}
        expect(response).to redirect_to(:controller => :sessions, :action => :new)
      end
    end
  end

end

