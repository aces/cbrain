
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

def mock_upload_file_param(name = "dummy_file")
  file_name = "cbrain_test_file_#{name}"
  FileUtils.touch("spec/fixtures/#{file_name}")
  file = fixture_file_upload("/#{file_name}")
  class << file; attr_reader :tempfile; end
  file
end

RSpec.describe UserfilesController, :type => :controller do
  let(:admin)                 { create(:admin_user, :login => "admin_user" ) }
  let(:site_manager)          { create(:site_manager) }
  let(:user)                  { create(:normal_user, :site => site_manager.site) }
  let(:admin_userfile)        { create(:single_file, :user => admin) }
  let(:site_manager_userfile) { create(:single_file, :user => site_manager) }
  let(:user_userfile)         { create(:single_file, :user => user) }
  let(:child_userfile)        { create(:single_file, :user => admin, :parent_id => admin_userfile.id) }
  let(:group_userfile)        { create(:single_file, :group_id => user.group_ids.last, :data_provider => data_provider) }
  let(:mock_userfile)         { mock_model(TextFile, :id => 1).as_null_object }
  let(:data_provider)         { create(:data_provider, :user => user, :online => true, :read_only => false) }

  after(:all) do
    FileUtils.rm(Dir.glob("spec/fixtures/cbrain_test_file_*"))
  end

  context "collection action" do

    describe "index" do

      context "with admin user" do
        before(:each) do
          session[:user_id] = admin.id
          admin_userfile
          site_manager_userfile
          user_userfile
        end

        it "should display all files if 'view all' is on" do
          get :index, "userfiles" => { "view_all" => "on" }
          expect(assigns[:userfiles].to_a).to match_array(Userfile.all)
        end

        it "should only display user's files if 'view all' is off" do
          get :index, "userfiles" => { "view_all" => "off" }
          expect(assigns[:userfiles].to_a).to match_array(Userfile.all(:conditions => {:user_id => admin.id}))
        end

        it "should not tree sort if tree sort not set" do
          expect(controller).not_to receive(:tree_sort_by_pairs)
          get :index, "userfiles" => { "tree_sort" => "off" }
        end

        it "should allow access to all files" do
          get :index, "userfiles" => { "tree_sort" => "on", "view_all" => "on" }
          expect(assigns[:userfiles].to_a).to match_array(Userfile.all)
        end


        context "filtering and sorting" do
          before(:each) do
            session[:userfiles] ||= {}
            session[:userfiles]["view_all"] = "on"
            session[:userfiles]["tree_sort"] = "off"
          end

          it "should filter by type" do
            file_collection = create(:file_collection)
            get :index, "userfiles" => { "filter_hash" => {"type" => "FileCollection"} }
            expect(assigns[:userfiles].to_a).to match_array([file_collection])
          end

          it "should filter by tag" do
            tag = create(:tag, :userfiles => [admin_userfile], :user => admin)
            get :index, "userfiles" => { "filter_tags_array" => tag.id.to_s }
            expect(assigns[:userfiles].to_a).to match_array([admin_userfile])
          end

          it "should filter by custom filter" do
            custom_filter = UserfileCustomFilter.create(:name => "userfile_filter", :user => admin, :data => {"file_name_type"=>"match", "file_name_term" => admin_userfile.name})
            get :index, "userfiles" => { "filter_custom_filters_array" => custom_filter.id.to_s }
            expect(assigns[:userfiles].to_a.first).to eq(admin_userfile)
          end

          it "should filter for no parent" do
            get :index, "userfiles" => { "filter_hash" => {"has_no_parent" => "true"} }
            expect(assigns[:userfiles].to_a).to match_array(Userfile.all(:conditions => {:parent_id => nil}))
          end

          it "should filter for no children" do
            admin_userfile
            child_userfile
            get :index, "userfiles" => { "filter_hash" => {"has_no_child" => "true"} }
            expect(assigns[:userfiles].to_a).to match_array(Userfile.all(:conditions => "userfiles.id NOT IN (SELECT parent_id FROM userfiles WHERE parent_id IS NOT NULL)"))
          end

          it "should sort by name" do
            get :index, "userfiles" => { "sort_hash" => {"order" => "userfiles.name"} }
            expect(assigns[:userfiles]).to eq(Userfile.all(:order => "userfiles.name"))
          end

          it "should be able to reverse sort" do
            get :index, "userfiles" => { "sort_hash" => {"order" => "userfiles.name", "dir" => "DESC"} }
            expect(assigns[:userfiles]).to eq(Userfile.all(:order => "userfiles.name DESC"))
          end

          it "should sort by type" do
            get :index, "userfiles" => { "sort_hash" => {"order" => "userfiles.type"} }
            expect(assigns[:userfiles]).to eq(Userfile.all(:order => "userfiles.type"))
          end

          it "should sort by owner name" do
            get :index, "userfiles" => { "sort_hash" => {"order" => "users.login"} }
            expect(assigns[:userfiles]).to eq(Userfile.all(:joins => :user, :order => "users.login"))
          end

          it "should sort by creation date" do
            get :index, "userfiles" => { "sort_hash" => {"order" => "userfiles.created_at"} }
            expect(assigns[:userfiles]).to eq(Userfile.all(:order => "userfiles.created_at"))
          end

          it "should sort by size" do
            get :index, "userfiles" => { "sort_hash" => {"order" => "userfiles.size"} }
            expect(assigns[:userfiles]).to eq(Userfile.all(:order => "userfiles.size"))
          end

          it "should sort by project name" do
            get :index, "userfiles" => { "sort_hash" => {"order" => "groups.name"} }
            expect(assigns[:userfiles]).to eq(Userfile.all(:joins => :group, :order => "groups.name"))
          end

          it "should sort by project access" do
            get :index, "userfiles" => { "sort_hash" => {"order" => "userfiles.group_writable"} }
            expect(assigns[:userfiles].map(&:group_writable)).to eq(Userfile.all(:order => "userfiles.group_writable").map(&:group_writable))
          end

          it "should sort by provider" do
            get :index, "userfiles" => { "sort_hash" => {"order" => "data_providers.name"} }
            expect(assigns[:userfiles]).to eq(Userfile.all(:joins => :data_provider, :order => "data_providers.name"))
          end
        end
      end



      context "with site manager" do
        before(:each) do
          session[:user_id] = site_manager.id
          admin_userfile
          site_manager_userfile
          user_userfile
        end

        it "should display site-associated files if 'view all' is on" do
          get :index, "userfiles" => { "view_all" => "on" }
          expect(assigns[:userfiles].to_a).to match_array(Userfile.find_all_accessible_by_user(site_manager, :access_requested => :read))
        end

        it "should only display user's files if 'view all' is off" do
          get :index, "userfiles" => { "view_all" => "off" }
          expect(assigns[:userfiles].to_a).to match_array([site_manager_userfile])
        end
      end



      context "with regular user" do
        before(:each) do
          session[:user_id] = user.id
          site_manager_userfile
          user_userfile
        end

        it "should display group-associated files if 'view all' is on" do
          group_userfile
          get :index, "userfiles" => { "view_all" => "on" }
          expect(assigns[:userfiles].to_a).to match_array([group_userfile, user_userfile])
        end

        it "should only display user's files if 'view all' is off" do
          get :index, "userfiles" => { "view_all" => "off" }
          expect(assigns[:userfiles].to_a).to match_array([user_userfile])
        end
      end
    end



    describe "new_parent_child" do
      before(:each) do
        session[:user_id] = admin.id
      end

      it "should render error message if no files are selected" do
        get :new_parent_child
        expect(response.body).to match(/warning/)
      end

       it "should render the parent-child selection template" do
         get :new_parent_child, "file_ids" => [admin_userfile.id.to_s, user_userfile.id.to_s]
         expect(response).to render_template("new_parent_child")
       end
    end



    describe "create_parent_child" do
      before(:each) do
        session[:user_id] = admin.id
      end

      it "should render an error message if no files selected" do
        post :create_parent_child, :parent_id => admin_userfile.id.to_s
        expect(flash[:error]).to match(/selected for this operation/)
      end

      it "should add children to parent" do
        post :create_parent_child, :child_ids => [admin_userfile.id.to_s], :parent_id => group_userfile.id.to_s
        admin_userfile.reload
        group_userfile.reload
        expect(admin_userfile.parent).to eq(group_userfile)
      end

      it "should redirect to index" do
        post :create_parent_child, :child_ids => [admin_userfile.id.to_s], :parent_id => group_userfile.id.to_s
        expect(response).to redirect_to(:action => :index)
      end
    end



    describe "sync_multiple" do
      let(:mock_status) {double("status", :status => "ProvNewer")}

      before(:each) do
        session[:user_id] = admin.id
        allow(mock_userfile).to receive(:local_sync_status).and_return(mock_status)
        allow(Userfile).to receive(:find_accessible_by_user).and_return([mock_userfile])
        allow(CBRAIN).to receive(:spawn_with_active_records).and_yield
      end

      it "should sync the file to the cache if it is in a valid state" do
        expect(mock_userfile).to receive(:sync_to_cache)
        get :sync_multiple, :file_ids => [1]
      end

      it "should not sync the file to the cache if it is not in a valid state" do
        allow(mock_status).to receive_message_chain(:status).and_return("InSync")
        expect(mock_userfile).not_to receive(:sync_to_cache)
        get :sync_multiple, :file_ids => [1]
      end
    end



    describe "create" do
      let(:mock_upload_stream) {mock_upload_file_param}

      before(:each) do
        session[:user_id] = admin.id
        allow(Message).to receive(:send_message)
        allow(File).to receive(:delete)
        allow(controller).to receive(:system)
      end

      it "should redirect to index if the upload file is blank" do
        post :create
        expect(response).to redirect_to(:action => :index)
      end

      it "should redirect to index if the upload file has an invalid name" do
        post :create, :upload_file => mock_upload_file_param(".BAD**")
        expect(response).to redirect_to(:action => :index)
      end



      context "saving a single file" do
        before(:each) do
          allow(CBRAIN).to receive(:spawn_with_active_records)
          allow(SingleFile).to receive(:new).and_return(mock_userfile.as_new_record)
        end



        context "when the save fails" do
          before(:each) do
            allow(mock_userfile).to receive(:save).and_return(false)
          end

          it "should redirect to index" do
            post :create, :upload_file => mock_upload_stream, :archive => "save"
            expect(response).to redirect_to(:action => :index)
          end

          it "should display an error message" do
            post :create, :upload_file => mock_upload_stream, :archive => "save"
            expect(flash[:error]).to match(/File .+ could not be added./)
          end
        end



        context "when the save succeeds" do
          before(:each) do
            allow(mock_userfile).to receive(:save).and_return(true)
            allow(CBRAIN).to receive(:spawn_with_active_records).and_yield
          end

          it "should display a flash message" do
            post :create, :upload_file => mock_upload_stream, :archive => "save"
            expect(flash[:notice]).to match(/File .+ being added in background./)
          end



          context "when the uploaded file is available" do
            before(:each) do
              allow(mock_upload_stream).to receive(:local_path).and_return("local_path")
            end

            it "should copy the file to the local cache" do
              expect(mock_userfile).to receive(:cache_copy_from_local_file)
              post :create, :upload_file => mock_upload_stream, :archive => "save"
            end
          end

          it "should save the userfile" do
            expect(mock_userfile).to receive(:save)
            post :create, :upload_file => mock_upload_stream, :archive => "save"
          end

          it "should update the new userfile's log" do
            expect(mock_userfile).to receive(:addlog_context)
            post :create, :upload_file => mock_upload_stream, :archive => "save"
          end

          it "should send a message that the upload is complete" do
            expect(Message).to receive(:send_message)
            post :create, :upload_file => mock_upload_stream, :archive => "save"
          end

          it "should redirect to the index" do
            post :create, :upload_file => mock_upload_stream, :archive => "save"
            expect(response).to redirect_to(:action => :index)
          end
        end
      end



      context "extracting from an archive" do
        before(:each) do
          allow(mock_upload_stream).to receive(:original_filename).and_return("archive.tgz")
          allow(FileCollection).to receive(:new).and_return(mock_userfile)
        end



        context "if the file is not an archive" do
          before(:each) do
            allow(mock_upload_stream).to receive(:original_filename).and_return("non_archive.na")
          end

          it "should redirect to the index" do
            post :create, :upload_file => mock_upload_stream, :archive => "file_collection"
            expect(response).to redirect_to(:action => :index)
          end

          it "should display an error message" do
            post :create, :upload_file => mock_upload_stream, :archive => "file_collection"
            expect(flash[:error]).to match(/Error: file .+ does not have one of the supported extensions:/)
          end
        end



        context "to create a collection" do

          context "when there is a collision" do
            let(:collision_file) {create(:userfile, :name => mock_upload_stream.original_filename.split('.')[0], :user => admin )}

            it "should redirect to index" do
              post :create, :upload_file => mock_upload_stream, :archive => "file_collection", :data_provider_id => collision_file.data_provider_id
              expect(response).to redirect_to(:action => :index)
            end

            it "should display an error message" do
              post :create, :upload_file => mock_upload_stream, :archive => "file_collection", :data_provider_id => collision_file.data_provider_id
              expect(flash[:error]).to match(/Collection '.+' already exists/)
            end
          end

          it "should create a FileCollection" do
            expect(FileCollection).to receive(:new).and_return(mock_userfile)
            post :create, :upload_file => mock_upload_stream, :archive => "file_collection"
          end



          context "when the save is successful" do
            before(:each) do
              allow(mock_userfile).to receive(:save).and_return(true)
              allow(CBRAIN).to receive(:spawn_with_active_records).and_yield
            end

            it "should extract the collection from the archive" do
              expect(mock_userfile).to receive(:extract_collection_from_archive_file)
              post :create, :upload_file => mock_upload_stream, :archive => "file_collection"
            end

            it "should send a message" do
              expect(Message).to receive(:send_message)
              post :create, :upload_file => mock_upload_stream, :archive => "file_collection"
            end

            it "should attempt to delete the tmp file" do
              expect(File).to receive(:delete)
              post :create, :upload_file => mock_upload_stream, :archive => "file_collection"
            end

            it "should display a flash message" do
              post :create, :upload_file => mock_upload_stream, :archive => "file_collection"
              expect(flash[:notice]).to match(/Collection '.+' created/)
            end

            it "should redirect to index" do
              post :create, :upload_file => mock_upload_stream, :archive => "file_collection"
              expect(response).to redirect_to(:action => :index)
            end
          end



          context "when the save is unsuccessful" do
            before(:each) do
              allow(mock_userfile).to receive(:save).and_return(false)
            end

            it "should display and error message" do
              post :create, :upload_file => mock_upload_stream, :archive => "file_collection"
              expect(flash[:error]).to match(/Collection '.+' could not be created/)
            end

            it "should redirect to index" do
              post :create, :upload_file => mock_upload_stream, :archive => "file_collection"
              expect(response).to redirect_to(:action => :index)
            end
          end
        end

        it "should display an error message if the archive parameters has an invalid value" do
          post :create, :upload_file => mock_upload_stream, :archive => "invalid_parameter"
          expect(flash[:error]).to match(/Unknown action/)
        end



        context "to create single files" do
          before(:each) do
            allow(CBRAIN).to receive(:spawn_with_active_records).and_yield
            allow(controller).to receive(:extract_from_archive)
          end

          it "should extract the collection from the archive" do
            expect(controller).to receive(:extract_from_archive)
            post :create, :upload_file => mock_upload_stream, :archive => "extract"
          end

          it "should attempt to delete the tmp file" do
            expect(File).to receive(:delete)
            post :create, :upload_file => mock_upload_stream, :archive => "extract"
          end

          it "should display a flash message" do
            post :create, :upload_file => mock_upload_stream, :archive => "extract"
            expect(flash[:notice]).to match(/Your files are being extracted/)
          end

          it "should redirect to the index" do
            post :create, :upload_file => mock_upload_stream, :archive => "extract"
            expect(response).to redirect_to(:action => :index)
          end
        end
      end
    end



    describe "update_multiple" do
      before(:each) do
        session[:user_id] = user.id
        allow(Userfile).to receive_message_chain(:find_all_accessible_by_user, :where, :all).and_return([mock_userfile])
      end

      context "when no operation is selected" do

        it "should display an error message" do
          post :update_multiple, :file_ids => [1]
          expect(flash[:error]).to match("Unknown operation")
        end

        it "should redirect to the index" do
          post :update_multiple, :file_ids => [1]
          expect(response).to redirect_to(:action => :index, :format => :html)
        end
      end

      it "should update tags when requested" do
        expect(mock_userfile).to receive(:set_tags_for_user)
        post :update_multiple, :file_ids => [1], :update_tags => true
      end

      it "should fail to update project when user does not have access" do
        group_id_hash = {:group_id => 4}
        post :update_multiple, :file_ids => [1], :update_projects => true, :userfile => group_id_hash
        expect(flash[:error]).to match(/project/)
      end

      it "should update permissions when requested" do
        permission_hash = {:group_writable => true}
        expect(mock_userfile).to receive(:update_attributes_with_logging)
        post :update_multiple, :file_ids => [1], :update_permissions => true, :userfile => permission_hash
      end

      it "should update the file type when requested" do
        expect(mock_userfile).to receive(:update_file_type)
        post :update_multiple, :file_ids => [1], :update_file_type => true
      end

      it "should display the number of succesful updates" do
        allow(mock_userfile).to receive(:send).and_return(true)
        post :update_multiple, :file_ids => [1], :update_tags => true
        expect(flash[:notice]).to match(" successful ")
      end

      it "should display the number of failed updates" do
        allow(mock_userfile).to receive(:send).and_return(false)
        post :update_multiple, :file_ids => [1], :update_tags => true
        expect(flash[:error]).to match(" unsuccessful ")
      end

      it "should redirect to the index" do
        post :update_multiple, :file_ids => [1], :update_tags => true
        expect(response).to redirect_to(:action => :index, :format => :html)
      end
    end



    describe "quality_control" do
      before(:each) do
        session[:user_id] = admin.id
      end

      it "should set the filelist variable" do
        filelist = ["1","2","3"]
        get :quality_control, :file_ids => filelist
        expect(assigns[:filelist]).to match(filelist)
      end
    end



    describe "quality_control_panel" do
      let(:available_tags) {double("tags").as_null_object}

      before(:each) do
        allow(controller).to receive(:current_user).and_return(admin)
        allow(admin).to receive(:available_tags).and_return(available_tags)
        allow(Userfile).to receive(:find_accessible_by_user).and_return(mock_userfile)
      end

      it "should find or create a 'PASS' tag" do
        expect(available_tags).to receive(:find_or_create_by_name_and_user_id_and_group_id).with("QC_PASS", anything, anything)
        post :quality_control_panel
      end

      it "should find or create a 'FAIL' tag" do
        expect(available_tags).to receive(:find_or_create_by_name_and_user_id_and_group_id).with("QC_FAIL", anything, anything)
        post :quality_control_panel
      end

      it "should find or create an 'UNKNOWN' tag" do
        expect(available_tags).to receive(:find_or_create_by_name_and_user_id_and_group_id).with("QC_UNKNOWN", anything, anything)
        post :quality_control_panel
      end

      it "should update the tags if any were given" do
        expect(mock_userfile).to receive(:set_tags_for_user)
        post :quality_control_panel, :pass => true, :index => 1
      end

      it "should find the current file" do
        expect(Userfile).to receive(:find_accessible_by_user)
        post :quality_control_panel
      end

      it "should use the userfile's partial if available" do
        allow(File).to receive(:exists?).and_return(true)
        post :quality_control_panel
        expect(assigns[:qc_view_file]).not_to match("_default")
      end

      it "should use the default partial if no userfile-specific partial available" do
        allow(File).to receive(:exists?).and_return(false)
        post :quality_control_panel
        expect(assigns[:qc_view_file]).to match("_default")
      end

      it "should render the quality control panel partial" do
        post :quality_control_panel
        expect(response).to render_template("quality_control_panel")
      end
    end



    describe "create_collection" do
      before(:each) do
        allow(controller).to receive(:current_user).and_return(admin)
        allow(FileCollection).to receive(:new).and_return(mock_userfile)
        allow(CBRAIN).to receive(:spawn_with_active_records).and_yield
        allow(Userfile).to receive(:find_accessible_by_user).and_return(mock_userfile)
        allow(DataProvider).to receive(:find_accessible_by_user).and_return([data_provider])
        allow(Message).to receive(:send_message)
        allow(DataProvider).to receive(:find)
      end

      it "should create a new collection" do
        expect(FileCollection).to receive(:new).and_return(mock_userfile)
        post :create_collection, :file_ids => [1], :data_provider_id_for_collection => data_provider.id
      end

      it "should merge the collections into a single one" do
        expect(mock_userfile).to receive(:merge_collections)
        post :create_collection, :file_ids => [1], :data_provider_id_for_collection => data_provider.id
      end

      it "should send a notice to the user if success happens" do
        allow(mock_userfile).to receive(:merge_collections).and_return(:success)
        expect(Message).to receive(:send_message).with(anything, hash_including(:message_type  => :notice))
        post :create_collection, :file_ids => [1], :data_provider_id_for_collection => data_provider.id
      end

      it "should send an error message to the user if collision happens" do
         allow(mock_userfile).to receive(:merge_collections).and_return(:collision)
         expect(Message).to receive(:send_message).with(anything, hash_including(:message_type  => :error))
         post :create_collection, :file_ids => [1], :data_provider_id_for_collection => data_provider.id
      end

      it "should send an error message to the user if exception happens" do
         allow(mock_userfile).to receive(:merge_collections).and_raise(CbrainError)
         expect(Message).to receive(:send_message).with(anything, hash_including(:message_type  => :error))
         post :create_collection, :file_ids => [1], :data_provider_id_for_collection => data_provider.id
      end

      it "should display a flash message" do
        post :create_collection, :file_ids => [1], :data_provider_id_for_collection => data_provider.id
        expect(flash[:notice]).to match(/Collection .+ is being created in background/)
      end

      it "should redirect to the index" do
        post :create_collection, :file_ids => [1], :data_provider_id_for_collection => data_provider.id
        expect(response).to redirect_to(:action => :index, :format => :html)
      end
    end



    describe "change_provider" do
      before(:each) do
        allow(controller).to receive(:current_user).and_return(admin)
        allow(admin).to receive(:license_agreement_set).and_return([])
        allow(admin).to receive(:unsigned_license_agreements).and_return([])
        allow(DataProvider).to receive_message_chain(:find_all_accessible_by_user, :where, :first).and_return(mock_model(DataProvider).as_null_object)
        allow(CBRAIN).to receive(:spawn_with_active_records).and_yield
        allow(Userfile).to receive(:find_accessible_by_user).and_return(mock_userfile)
        allow(mock_userfile).to receive(:provider_move_to_otherprovider)
        allow(mock_userfile).to receive(:provider_copy_to_otherprovider)
      end

      context "when the other data povider is not found" do
        before(:each) do
          allow(DataProvider).to receive_message_chain(:find_all_accessible_by_user, :where, :first).and_return(nil)
        end

        it "should display an error message" do
          post :change_provider, :file_ids => [1], :data_provider_id_for_mv_cp => data_provider.id
          expect(flash[:error]).to match(/Data provider .* not accessible/)
        end

        it "should redirect to the index" do
          post :change_provider, :file_ids => [1]
          expect(response).to redirect_to(:action => :index, :format => :html)
        end
      end

      context "when moving a file" do

        it "should check if the user has owner access" do
          expect(mock_userfile).to receive(:has_owner_access?)
          post :change_provider, :file_ids => [1], :move => true, :data_provider_id_for_mv_cp => data_provider.id
        end

        it "should attempt to move the file if the user has owner access" do
          allow(mock_userfile).to receive(:has_owner_access?).and_return(true)
          expect(mock_userfile).to receive(:provider_move_to_otherprovider)
          post :change_provider, :file_ids => [1], :move => true, :data_provider_id_for_mv_cp => data_provider.id
        end

        it "should not attempt to move the file if the user does not have owner access" do
          allow(mock_userfile).to receive(:has_owner_access?).and_return(false)
          expect(mock_userfile).not_to receive(:provider_move_to_otherprovider)
          post :change_provider, :file_ids => [1], :move => true, :data_provider_id_for_mv_cp => data_provider.id
        end
      end

      it "should attempt to copy the file when requested" do
        expect(mock_userfile).to receive(:provider_copy_to_otherprovider)
        post :change_provider, :file_ids => [1], :copy => true, :data_provider_id_for_mv_cp => data_provider.id
      end

      it "should send message about successes" do
        allow(mock_userfile).to receive(:provider_copy_to_otherprovider).and_return(true)
        expect(Message).to receive(:send_message).with(anything, hash_including(:message_type  => :notice))
        post :change_provider, :file_ids => [1], :copy => true, :data_provider_id_for_mv_cp => data_provider.id
      end

      it "should send message about failures" do
        allow(mock_userfile).to receive(:provider_copy_to_otherprovider).and_return(false)
        expect(Message).to receive(:send_message).with(anything, hash_including(:message_type  => :error))
        post :change_provider, :file_ids => [1], :copy => true, :data_provider_id_for_mv_cp => data_provider.id
      end

      it "should display a flash message" do
        post :change_provider, :file_ids => [1], :data_provider_id_for_mv_cp => data_provider.id
        expect(flash[:notice]).to match(/Your files are being .+ in the background/)
      end

      it "should redirect to the index" do
        post :change_provider, :file_ids => [1]
        expect(response).to redirect_to(:action => :index, :format => :html)
      end
    end



    describe "manage_persistent" do
      let(:current_session) {double("current_session", :persistent_userfile_ids_list => [1]).as_null_object}

      before(:each) do
        allow(controller).to receive(:current_user).and_return(admin)
        allow(controller).to receive(:current_session).and_return(current_session)
      end

      it "should clear the persistent ids if the operation is 'clear'" do
        expect(current_session).to receive(:persistent_userfile_ids_clear).and_return(1)
        post :manage_persistent, :file_ids => [1], :operation => "clear"
      end

      it "should clear and then add the persistent ids if the operation is 'replace'" do
        expect(current_session).to receive(:persistent_userfile_ids_clear).ordered.and_return(1)
        expect(current_session).to receive(:persistent_userfile_ids_add).ordered.and_return(1)
        post :manage_persistent, :file_ids => [1], :operation => "replace"
      end

      it "should add the persistent ids if the operation is 'add'" do
        expect(current_session).to receive(:persistent_userfile_ids_add).ordered.and_return(1)
        post :manage_persistent, :file_ids => [1], :operation => "add"
      end

      it "should remove the persistent ids if the operation is 'remove'" do
        expect(current_session).to receive(:persistent_userfile_ids_remove).ordered.and_return(1)
        post :manage_persistent, :file_ids => [1], :operation => "remove"
      end

      it "should display a report if the persistent file ids changed" do
        allow(current_session).to receive(:persistent_userfile_ids_list).and_return([1])
        post :manage_persistent, :file_ids => [1], :operation => "remove"
        expect(flash[:notice]).to match(/Total of .* now in the persistent list of files/)
      end

      it "should display a message saying no file ids were changed if that is the case" do
        allow(current_session).to receive(:persistent_userfile_ids_remove).and_return(0)
        post :manage_persistent, :file_ids => [1], :operation => "remove"
        expect(flash[:notice]).to match("No changes made to the persistent list of userfiles")
      end

      it "should redirect to the index" do
        post :manage_persistent, :file_ids => [1], :operation => "remove"
        expect(response).to redirect_to(:action => :index)
      end
    end



    describe "delete_files" do
      before(:each) do
        allow(controller).to receive(:current_user).and_return(admin)
        allow(mock_userfile).to receive(:id).and_return(1)
        allow(Userfile).to receive_message_chain(:accessible_for_user, :where).and_return([mock_userfile])
        allow(CBRAIN).to receive(:spawn_with_active_records).and_yield
      end

      it "should display error message if userfiles is not accessible by user" do
        allow(Userfile).to receive_message_chain(:accessible_for_user, :where).and_return([])
        delete :delete_files, :file_ids => [1]
        expect(flash[:error]).to match("not have acces")
      end

      it "should destroy the userfiles" do
        expect(mock_userfile).to receive(:destroy)
        delete :delete_files, :file_ids => [1]
      end

      it "should announce that files are being deleted in the background" do
        allow(mock_userfile).to receive_message_chain(:data_provider, :is_browsable?).and_return(false)
        allow(mock_userfile).to receive_message_chain(:data_provider, :meta, :[], :blank?).and_return(false)
        delete :delete_files, :file_ids => [1]
        expect(flash[:notice]).to match("deleted in background")
      end

      it "should redirect to the index" do
        delete :delete_files, :file_ids => [1]
        expect(response).to redirect_to(:action => :index)
      end
    end



    describe "download" do
      before(:each) do
        allow(controller).to receive(:current_user).and_return(admin)
        allow(controller).to receive(:send_file)
        allow(controller).to receive(:sleep)
        allow(controller).to receive(:render)
        allow(Userfile).to receive(:find_accessible_by_user).and_return([mock_userfile])
        allow(mock_userfile).to receive(:size).and_return(5)
        allow(CBRAIN).to receive(:spawn_fully_independent)
      end

      context "when an illegal file name is given" do
        before(:each) do
          allow(Userfile).to receive(:is_legal_filename?).and_return(false)
        end

        it "should display an error message" do
          get :download, :file_ids => [1], :specified_filename => "not_valid"
          expect(flash[:error]).to match(/filename '.+' is not acceptable/)
        end

        it "should redirect to the index" do
          get :download, :file_ids => [1], :specified_filename => "not_valid"
          expect(response).to redirect_to(:action => :index, :format => :html)
        end
      end

      it "should find the userfiles" do
        expect(Userfile).to receive(:find_accessible_by_user).and_return([mock_userfile])
        get :download, :file_ids => [1]
      end



      context "when the max download size is exceeded" do
        before(:each) do
          allow(mock_userfile).to receive(:size).and_return(UserfilesController::MAX_DOWNLOAD_MEGABYTES.megabytes + 1)
        end

        it "should display an error message" do
          get :download, :file_ids => [1]
          expect(flash[:error]).to match("You cannot download data that exceeds")
        end

        it "should redirect to the index" do
          get :download, :file_ids => [1]
          expect(response).to redirect_to(:action => :index, :format => :html)
        end
      end

      it "should sync the files to the cache" do
        expect(mock_userfile).to receive(:sync_to_cache)
        get :download, :file_ids => [1]
      end

      it "should send the file if it is one SingleFile" do
        allow(mock_userfile).to receive(:is_a?).and_return(true)
        expect(controller).to   receive(:send_file)
        get :download, :file_ids => [1]
      end

      it "should create a tar for multiple files" do
        expect(controller).to receive(:create_relocatable_tar_for_userfiles)
        allow(Userfile).to    receive(:find_accessible_by_user).and_return([mock_userfile, mock_userfile])
        get :download, :file_ids => [1,2]
      end

      it "should send the tar file for multiple files" do
        expect(controller).to receive(:send_file)
        allow(Userfile).to    receive(:find_accessible_by_user).and_return([mock_userfile, mock_userfile])
        get :download, :file_ids => [1,2]
      end

      it "should delete the tar file" do
        allow(CBRAIN).to   receive(:spawn_fully_independent).and_yield
        allow(Userfile).to receive(:find_accessible_by_user).and_return([mock_userfile, mock_userfile])
        expect(File).to    receive(:unlink)
        get :download, :file_ids => [1,2]
      end
    end



    describe "compress" do
      let(:mock_singlefile) {mock_model(SingleFile, :name => "file_name").as_null_object}

      before(:each) do
        allow(controller).to      receive(:current_user).and_return(admin)
        allow(Userfile).to        receive(:find_accessible_by_user).and_return([mock_singlefile])
        allow(mock_singlefile).to receive_message_chain(:data_provider, :read_only?).and_return(false)
        allow(Userfile).to        receive_message_chain(:where, :first).and_return(nil)
        allow(CBRAIN).to          receive(:spawn_with_active_records)
      end

      it "should display an error message if the file is not a SingleFile" do
        allow(Userfile).to receive(:find_accessible_by_user).and_return([mock_model(FileCollection).as_null_object])
        post :compress, :file_ids => [1]
        expect(flash[:error]).to match("Not a SingleFile")
      end

      it "should display an error message if the data provider is not writable" do
        allow(mock_singlefile).to receive_message_chain(:data_provider, :read_only?).and_return(true)
        post :compress, :file_ids => [1]
        expect(flash[:error]).to match("Data Provider not writable")
      end

      it "should display an error message file name already exists" do
        allow(Userfile).to receive_message_chain(:where, :exists?).and_return(true)
        post :compress, :file_ids => [1]
        expect(flash[:error]).to match("Filename collision")
      end



      context "when compressing" do
        before(:each) do
          allow(Userfile).to   receive_message_chain(:where, :exists?).and_return(false)
          allow(CBRAIN).to     receive(:spawn_with_active_records).and_yield
          allow(SyncStatus).to receive(:ready_to_modify_cache).and_yield
          allow(controller).to receive(:system)
          allow(File).to       receive(:rename)
          allow(Message).to    receive(:send_message)
        end

        it "should rename the file on the provider" do
          expect(mock_singlefile).to receive(:provider_rename)
          post :compress, :file_ids => [mock_singlefile.id]
        end

        it "should sync the file to the cache" do
          expect(mock_singlefile).to receive(:sync_to_cache)
          post :compress, :file_ids => [1]
        end

        it "should ensure that the cache is ready to be modified" do
          expect(SyncStatus).to receive(:ready_to_modify_cache)
          post :compress, :file_ids => [1]
        end

        it "should compress the file if it is uncompressed" do
          expect(controller).to receive(:system).with(/^gzip/)
          post :compress, :file_ids => [1]
        end

        it "should uncompress the file if it is compressed" do
          allow(mock_singlefile).to receive(:name).and_return("file_name.gz")
          expect(controller).to receive(:system).with(/^gunzip/)
          post :compress, :file_ids => [1]
        end

        it "should crush the original file" do
          expect(File).to receive(:rename)
          post :compress, :file_ids => [1]
        end

        it "should sync the file to the provider" do
          expect(mock_singlefile).to receive(:sync_to_provider)
          post :compress, :file_ids => [1]
        end

        it "should send a message to the user" do
          expect(Message).to receive(:send_message)
          post :compress, :file_ids => [1]
        end
      end

      it "should redirect to the index" do
        allow(Userfile).to receive_message_chain(:where, :exists?).and_return(true)
        post :compress, :file_ids => [1]
        expect(response).to redirect_to(:action => :index, :format => :html)
      end
    end
  end



  context "member action" do
    before(:each) do
      session[:user_id] = admin.id
    end



    describe "content" do
      let(:content_loader) {double("content_loader", :method => :content_loader_method).as_null_object}

      before(:each) do
        allow(Userfile).to receive(:find_accessible_by_user).and_return(mock_userfile)
        allow(mock_userfile).to receive(:find_content_loader).and_return(content_loader)
        allow(mock_userfile).to receive(:content_loader_method)
        allow(controller).to receive(:send_file)
        allow(controller).to receive(:render)
      end

      it "should determine if the userfile has a content loader" do
        expect(mock_userfile).to receive(:find_content_loader).and_return(nil)
        get :content, :id => 1
      end

      it "should send file given by the content loader for a send_file loader" do
        allow(content_loader).to receive(:type).and_return(:send_file)
        allow(mock_userfile).to receive(:content_loader_method).and_return("path")
        expect(controller).to receive(:send_file).with("path")
        get :content, :id => 1
      end

      it "should send zipped data given by the content method" do
        allow(content_loader).to receive(:type).and_return(:gzip)
        get :content, :id => 1
        expect(response.headers["Content-Encoding"]).to eq("gzip")
      end

      it "should render any other content defined by the content loader" do
        type    = :text
        content = "content"
        allow(content_loader).to receive(:type).and_return(type)
        allow(mock_userfile).to receive(:content_loader_method).and_return(content)
        expect(controller).to receive(:render).with(type => content)
        get :content, :id => 1
      end

      it "should send the userfile itself if no content given" do
        allow(mock_userfile).to receive(:find_content_loader).and_return(nil)
        allow(mock_userfile).to receive(:cache_full_path).and_return("path")
        expect(controller).to   receive(:send_file).with("path", anything)
        get :content, :id => 1
      end
    end



    describe "display" do
      let(:mock_viewer) {Userfile::Viewer.new(mock_userfile.class, {:userfile_class => mock_userfile.class.name, :name => "Text File", :partial => "partial"})}

      before(:each) do
        allow(mock_userfile).to receive(:find_viewer).and_return(mock_viewer)
        allow(Userfile).to      receive(:find_accessible_by_user).and_return(mock_userfile)
        allow(File).to          receive(:exists?).and_return(true)
      end

      it "should render :file if viewer exist" do
        allow(mock_viewer).to receive_message_chain(:partial_path,:to_s).and_return("file")
        get :display, :viewer => "Text File", :apply_div => "false", :id => 1
        expect(response).to render_template(:file => "file")
      end

      it "should to try find a partial with the viewer name if the userfile doesn't have an associated viewer" do
        allow(mock_userfile).to receive(:find_viewer).and_return(nil)
        expect(File).to receive(:exists?).and_return(true)
        get :display, :id => 1, :viewer => "hello"
      end

      it "should render the display partial a div is requested" do
        get :display, :viewer => "Text File", :id => 1
        expect(response).to render_template(:display)
      end

      it "should render a warning if no viewer partial is found" do
        get :display, :id => 1, :viewer => "Unknown viewer"
        expect(response.body).to match(/Could not find viewer/)
      end
    end



    describe "show" do
      let(:mock_status) {double("status", :status => "ProvNewer")}

      before(:each) do
        allow(Userfile).to receive(:find_accessible_by_user).and_return(mock_userfile)
        allow(mock_userfile).to receive(:local_sync_status).and_return(mock_status)
      end

      it "should find the requested userfile" do
        expect(Userfile).to receive(:find_accessible_by_user).and_return(mock_userfile)
        get :show, :id => 1
      end

      it "should retreive the sync status" do
        allow(mock_status).to receive(:status).and_return("userfile_status")
        get :show, :id => 1
        expect(assigns[:sync_status]).to eq("userfile_status")
      end

      it "should set the sync status to 'Prov Newer' if it isn't set yet" do
        allow(mock_userfile).to receive(:local_sync_status).and_return(nil)
        get :show, :id => 1
        expect(assigns[:sync_status]).to eq("ProvNewer")
      end

      it "should retreive the default viewer" do
        allow(mock_userfile).to receive_message_chain(:viewers, :first).and_return("default_viewer")
        get :show, :id => 1
        expect(assigns[:viewer]).to eq("default_viewer")
      end

      it "should retreive the userfile's log" do
        allow(mock_userfile).to receive(:getlog).and_return("userfile_log")
        get :show, :id => 1
        expect(assigns[:log]).to eq("userfile_log")
      end

      it "should set the log to nil if an error occurs" do
        allow(mock_userfile).to receive(:getlog).and_raise(StandardError)
        get :show, :id => 1
        expect(assigns[:log]).to be_nil
      end

      it "should render the show page" do
        get :show, :id => 1
        expect(response).to render_template("show")
      end
    end

    describe "update" do
      before(:each) do
        allow(Userfile).to receive(:find_accessible_by_user).and_return(mock_userfile)
        allow(Userfile).to receive(:is_legal_filename?).and_return(true)
      end

      it "should find the requested file" do
        expect(Userfile).to receive(:find_accessible_by_user).and_return(mock_userfile)
        put :update, :id => 1
      end

      it "it should display an error message when attempting to update to an invalid type" do
        text_file = create(:text_file)
        allow(Userfile).to receive_message_chain(:find_all_accessible_by_user, :where, :all).and_return([text_file])
        put :update_multiple, :update_file_type => true, :file_ids => [text_file.id], :file_type => "InvalidType"
        expect(flash[:error]).to match("unsuccessful for 1")
      end

      it "should set tags" do
        expect(mock_userfile).to receive(:set_tags_for_user)
        put :update, :id => 1
      end

      it "should update attributes" do
        expect(mock_userfile).to receive(:save_with_logging)
        put :update, :id => 1
      end

      context "when the update is successful" do
        before(:each) do
          allow(mock_userfile).to receive(:update_attributes).and_return(true)
        end



        context "and the name is changed" do
          before(:each) do
            allow(mock_userfile).to receive(:name).and_return("old_name")
            allow(mock_userfile).to receive(:provider_rename).and_return(true)
          end

          it "should attempt to rename the file on the provider" do
            expect(mock_userfile).to receive(:provider_rename)
            put :update, :id => 1, :userfile => {:name => "new_name"}
          end

          it "should not save if the provider rename was not successful" do
            allow(mock_userfile).to receive(:provider_rename).and_return(false)
            expect(mock_userfile).not_to receive(:save)
            put :update, :id => 1, :userfile => {:name => "new_name"}
          end
        end

        it "should display a flash message" do
          put :update, :id => 1
          expect(flash[:notice]).to match("successfully updated")
        end

        it "should redirect to the show page" do
          put :update, :id => 1
          expect(response).to redirect_to(:action => :show)
        end
      end



      context "when the update is unsuccesful" do

        it "should render the show action" do
          allow(mock_userfile).to receive(:errors).and_return({:type => "Some errors"})
          put :update, :id => 1
          expect(response).to render_template(:show)
        end
      end
    end


    describe "extract_from_collection" do
      let(:mock_collection) {mock_model(FileCollection).as_null_object}

      before(:each) do
        allow(FileCollection).to receive(:find_accessible_by_user).and_return(mock_collection)
        allow(SingleFile).to receive(:new).and_return(mock_userfile)
        allow(Dir).to receive(:chdir).and_yield
      end



      context "when no files are selected" do

        it "should display a flash message" do
          post :extract_from_collection, :id => 1
          expect(flash[:notice]).to match("No files selected for extraction")
        end

        it "should redirect to the edit page" do
          post :extract_from_collection, :id => 1
          expect(response).to redirect_to(:action => :show, :id => 1)
        end
      end

      it "should find the collection" do
         expect(FileCollection).to receive(:find_accessible_by_user).and_return(mock_collection)
         post :extract_from_collection, :id => 1, :file_names => ["file_name"]
      end

      it "should create a new single file" do
        expect(SingleFile).to receive(:new).and_return(mock_userfile)
        post :extract_from_collection, :id => 1, :file_names => ["file_name"]
      end

      it "should save the new file" do
        expect(mock_userfile).to receive(:save).and_return(true)
        post :extract_from_collection, :id => 1, :file_names => ["file_name"]
      end



      context "when the save is successful" do
        before(:each) do
          allow(mock_userfile).to receive(:save).and_return(true)
        end

        it "should copy the file to the cache" do
          expect(mock_userfile).to receive(:cache_copy_from_local_file)
          post :extract_from_collection, :id => 1, :file_names => ["file_name"]
        end

        it "should display a flash message" do
          post :extract_from_collection, :id => 1, :file_names => ["file_name"]
          expect(flash[:notice]).to match("successfuly extracted")
        end
      end



      context "when the save is unsuccessful" do
        before(:each) do
          allow(mock_userfile).to receive(:save).and_return(false)
        end

        it "should not attempt to copy the file to the cache"do
          expect(mock_userfile).not_to receive(:cache_copy_from_local_file)
          post :extract_from_collection, :id => 1, :file_names => ["file_name"]
        end

        it "should display an error message" do
          post :extract_from_collection, :id => 1, :file_names => ["file_name"]
          expect(flash[:error]).to match("could not be extracted")
        end
      end

      it "should redirect to the index" do
        post :extract_from_collection, :id => 1, :file_names => ["file_name"]
        expect(response).to redirect_to(:action => :index)
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
  end

end

