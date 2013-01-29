
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

describe DataProvidersController do
  let(:data_provider) {mock_model(DataProvider).as_null_object}
  let(:admin_user) {Factory.create(:admin_user)}
  
  context "with an admin user" do
    before(:each) do
      session[:user_id] = admin_user.id
    end

    context "collection action" do
      describe "index" do
        before(:each) do
          DataProvider.stub!(:find_all_accessible_by_user).and_return(double("provider_scope", :includes => "includes"))
          controller.stub!(:base_filtered_scope)
          controller.stub!(:base_sorted_scope).and_return([data_provider])
        end
        it "should use the basic filtered scope" do
          controller.should_receive(:base_filtered_scope)
          get :index
        end
        it "should assign @data_providers" do
          get :index
          assigns[:data_providers].should == [data_provider]
        end
        it "should render the index page" do
         get :index
         response.should render_template("index")
        end
      end
      describe "new" do
        it "should create a new data provider" do
          DataProvider.should_receive(:new)
          get :new
        end
        it "should get the type list" do
          controller.should_receive(:get_type_list)
          get :new
        end
        it "should render the new page" do
          get :new
          response.should render_template(:partial => "_new")
        end
      end
      describe "create" do
        before(:each) do
          DataProvider.stub!(:sti_new).and_return(data_provider.as_new_record)
        end
        context "when save is successful" do
          before(:each) do
            data_provider.stub!(:save).and_return(true)
            data_provider.stub_chain(:errors, :empty?).and_return(true)
          end
          it "should add the meta data" do
            controller.should_receive(:add_meta_data_from_form)
            post :create, :format => :js
          end

          it "should display a flash message" do
            post :create, :format => :js
            flash[:notice].should include_text("created")
          end

          it "should redirect to index" do
            post :create, :format => :js
            response.should redirect_to(:action => :index, :format => :js)
          end
        end
        context "when save fails" do
          before(:each) do
            data_provider.stub!(:save).and_return(false)
            data_provider.stub_chain(:errors, :empty?).and_return(false)
          end
          it "should not add the meta data" do
            controller.should_not_receive(:add_meta_data_from_form)
            post :create, :format => :js
          end

          it "should render failed creation partial" do
            post :create, :format => :js
            response.should render_template(:partial => "shared/_failed_create")
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
        DataProvider.stub!(:find).and_return(data_provider)
      end
      describe "show" do
        it "should raise an cb_notice if the provider is not accessible by the current user" do
          data_provider.stub(:can_be_accessed_by?).and_return(false)
          get :show, :id => 1
          response.should redirect_to(:action => :index)
        end
        it "should render the show page" do
          get :show, :id => 1
          response.should render_template("show")
        end
      end
      describe "update" do
        before(:each) do
          data_provider.stub!(:has_owner_access?).and_return(true)
          data_provider.stub!(:update_attributes_with_logging).and_return(true)
        end
        it "should check if user has owner access" do
          data_provider.should_receive(:has_owner_access?)
          put :update, :id => 1
        end
        it "should update attrubutes" do
          data_provider.should_receive(:update_attributes_with_logging)
          put :update, :id => 1
        end
        context "user does not have access" do
          before(:each) do
            data_provider.stub!(:has_owner_access?).and_return(false)
          end
          it "should display an error message" do
            put :update, :id => 1
            flash[:error].should_not be_blank
          end
          it "should redirect to show" do
            put :update, :id => 1
            response.should redirect_to(:action => :show)
          end
        end
        context "success" do
          it "should add meta data" do
            controller.should_receive(:add_meta_data_from_form)
            put :update, :id => 1
          end
          it "should display success message" do
            put :update, :id => 1
            flash[:notice].should include_text("success")
          end
          it "should redirect to index" do
            put :update, :id => 1
            response.should redirect_to(:action => :show)
          end
        end
        context "failure" do
          before(:each) do
            data_provider.stub!(:update_attributes_with_logging).and_return(false)
          end
          it "should reload the data_provider" do
            data_provider.should_receive(:reload)
            put :update, :id => 1
          end
          it "should redirect to index" do
            put :update, :id => 1
            response.should render_template(:show)
          end
        end
      end
      describe "destroy" do
        before(:each) do
          DataProvider.stub!(:find_accessible_by_user).and_return(data_provider)
          data_provider.stub!(:has_owner_access?).and_return(true)
        end
        it "should display an error if the user does not have owner access" do
          data_provider.stub!(:has_owner_access?).and_return(false)
          delete :destroy, :id => 1
          flash[:error].should_not be_blank
        end
        it "should destroy the data provider" do
          data_provider.should_receive(:destroy)
          delete :destroy, :id => 1
        end
        it "should redirect to index" do
          delete :destroy, :id => 1
          response.should redirect_to(:action => :index)
        end
        context "provider not destroyed" do
          before(:each) do
            data_provider.stub!(:destroy).and_raise(ActiveRecord::DeleteRestrictionError.new("Not Destroyed!!!"))
          end
          it "should display an error message" do
            delete :destroy, :id => 1
            flash[:error].should include_text("Not Destroyed!!!")
          end
          it "should redirect to index" do
            delete :destroy, :id => 1
            response.should redirect_to(:action => :index)
          end
        end
      end
      
      describe "is_alive" do
        before(:each) do
          DataProvider.stub!(:find_accessible_by_user).and_return(data_provider)
        end
        it "should check if the data provider is alive" do
          data_provider.should_receive(:is_alive?)
          get :is_alive, :id => 1
        end
        it "should return yes if provider is alive" do
          data_provider.stub!(:is_alive?).and_return(true)
          get :is_alive, :id => 1
          response.body.should include_text(/yes/i)
        end
        it "should return no if provider is not alive" do
          data_provider.stub!(:is_alive?).and_return(false)
          get :is_alive, :id => 1
          response.body.should include_text(/no/i)
        end
      end
      describe "browse" do
        let(:file_info_list) {[double("file_info").as_null_object]}
        
        before(:each) do
          DataProvider.stub!(:find_accessible_by_user).and_return(data_provider)
          data_provider.stub!(:is_browsable?).and_return(true)
          data_provider.stub!(:online?).and_return(true)
          controller.stub!(:get_recent_provider_list_all).and_return(file_info_list)
        end
        context "provider is not browsable" do
          before(:each) do
            data_provider.stub!(:is_browsable?).and_return(false)
          end
          it "should display an error message" do
            get :browse, :id => 1
            flash[:error].should_not be_blank
          end
          it "should redirect to index" do
            get :browse, :id => 1
            response.should redirect_to(:action => :index)
          end
        end
        context "provider is not browsable" do
          before(:each) do
            data_provider.stub!(:online?).and_return(false)
          end
          it "should display an error message" do
            get :browse, :id => 1
            flash[:error].should_not be_blank
          end
          it "should redirect to index" do
            get :browse, :id => 1
            response.should redirect_to(:action => :index)
          end
        end
        it "should retrieve the list of files" do
          controller.should_receive(:get_recent_provider_list_all).and_return(file_info_list)
          get :browse, :id => 1
        end
        it "should iterate over the file list" do
          file_info_list.should_receive(:each)
          get :browse, :id => 1
        end
        it "should check that the filenames are legal" do
          Userfile.should_receive(:is_legal_filename?)
          get :browse, :id => 1
        end
        it "should do the search if a parameter is given" do
          file_info_list.should_receive(:select).and_return([])
          get :browse, :id => 1, :search => "hi"
        end
        it "should paginate the list" do
          WillPaginate::Collection.should_receive(:create)
          get :browse, :id => 1
        end
        it "should render the browse page" do
          get :browse, :id => 1
          response.should render_template("browse")
        end    
      end
      describe "register" do
        let(:registered_file) {mock_model(SingleFile, :save => true).as_null_object.as_new_record}
        
        before(:each) do
          DataProvider.stub!(:find_accessible_by_user).and_return(data_provider)
          data_provider.stub!(:is_browsable?).and_return(true)
          CBRAIN.stub!(:spawn_with_active_records)
          SingleFile.stub!(:new).and_return(registered_file)
          registered_file.stub!(:save).and_return(true)
        end
        
        it "should check if the data_provider is browsable" do
          data_provider.should_receive(:is_browsable?)
          post :register, :id => 1, :basenames => ["a_file"]
        end
        
        context "provider is not browsable" do
          before(:each) do
            data_provider.stub!(:is_browsable?).and_return(false)
          end
          it "should display an error message" do
            post :register, :id => 1, :basenames => ["a_file"]
            flash[:error].should_not be_blank
          end 
          it "should redirect to index" do
            post :register, :id => 1, :basenames => ["a_file"]
            response.should redirect_to(:action => :index)
          end
        end
        
        context "register only" do
          it "should set the sizes in a separate process" do
            CBRAIN.should_receive(:spawn_with_active_records)
            post :register, :id => 1, :basenames => ["a_file"]
          end
          it "should display that registration was a success" do
            post :register, :id => 1, :basenames => ["a_file"]
            flash[:notice].should include_text(/\bregistered\b/i)
          end
          it "should redirect to browse" do
            post :register, :id => 1, :basenames => ["a_file"]
            response.should redirect_to(:action => :browse)
          end
        end
        context "doing move or copy" do
          it "should check for collisions" do
            Userfile.should_receive(:where).and_return(double("registered files").as_null_object)
            post :register, :id => 1, :basenames => ["a_file"], :auto_do => "MOVE"
          end
          it "should spawn a background process for moving" do
            CBRAIN.should_receive(:spawn_with_active_records)
            post :register, :id => 1, :basenames => ["a_file"], :auto_do => "MOVE"
          end
          it "should redirect to browse" do
            post :register, :id => 1, :basenames => ["a_file"], :auto_do => "MOVE"
            response.should redirect_to(:action => :browse)
          end
          it "should move the file if a move is requested" do
            CBRAIN.stub!(:spawn_with_active_records).and_yield
            registered_file.should_receive(:provider_move_to_otherprovider)
            post :register, :id => 1, :basenames => ["a_file"], :auto_do => "MOVE"
          end
          it "should copy the file if a copy is requested" do
            CBRAIN.stub!(:spawn_with_active_records).and_yield
            registered_file.should_receive(:provider_copy_to_otherprovider)
            post :register, :id => 1, :basenames => ["a_file"], :auto_do => "COPY"
          end
        end
        
      end
    end
  end
    
 
  context "when the user is not logged in" do
    describe "index" do
      it "should redirect the login page" do
        get :index
        response.should redirect_to(:controller => :sessions, :action => :new)
      end
    end
    describe "new" do
      it "should redirect the login page" do
        get :new
        response.should redirect_to(:controller => :sessions, :action => :new)
      end
    end
    describe "show" do
      it "should redirect the login page" do
        get :show, :id => 1
        response.should redirect_to(:controller => :sessions, :action => :new)
      end
    end
    describe "create" do
      it "should redirect the login page" do
        post :create
        response.should redirect_to(:controller => :sessions, :action => :new)
      end
    end
    describe "dp_access" do
      it "should redirect the login page" do
        post :dp_access
        response.should redirect_to(:controller => :sessions, :action => :new)
      end
    end
    describe "create" do
      it "should redirect the login page" do
        post :dp_transfers
        response.should redirect_to(:controller => :sessions, :action => :new)
      end
    end
    describe "update" do
      it "should redirect the login page" do
        put :update, :id => 1
        response.should redirect_to(:controller => :sessions, :action => :new)
      end
    end
    describe "destroy" do
      it "should redirect the login page" do
        delete :destroy, :id => 1
        response.should redirect_to(:controller => :sessions, :action => :new)
      end
    end
    describe "is_alive" do
      it "should redirect the login page" do
        delete :is_alive, :id => 1
        response.should redirect_to(:controller => :sessions, :action => :new)
      end
    end
    describe "browse" do
      it "should redirect the login page" do
        delete :browse, :id => 1
        response.should redirect_to(:controller => :sessions, :action => :new)
      end
    end
    describe "register" do
      it "should redirect the login page" do
        delete :register, :id => 1
        response.should redirect_to(:controller => :sessions, :action => :new)
      end
    end
  end
  
end

