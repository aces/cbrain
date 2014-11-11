
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

def mock_upload_file_param(name = "dummy_file")
  file_name = "cbrain_test_file_#{name}"
  FileUtils.touch("spec/fixtures/#{file_name}")
  file = fixture_file_upload("/#{file_name}")
  class << file; attr_reader :tempfile; end
  file
end

describe UserfilesController do
  let!(:admin)                 {Factory.create(:admin_user, :login => "admin_user" )}
  let!(:site_manager)          {Factory.create(:site_manager)}
  let!(:user)                  {Factory.create(:normal_user, :site => site_manager.site)}
  let!(:admin_userfile)        {Factory.create(:single_file, :user => admin)}
  let!(:site_manager_userfile) {Factory.create(:single_file, :user => site_manager)}
  let!(:user_userfile)         {Factory.create(:single_file, :user => user)}
  let!(:child_userfile)        {Factory.create(:single_file, :user => admin, :parent => admin_userfile)}
  let!(:group_userfile)        {Factory.create(:single_file, :group => user.groups.last, :data_provider => data_provider)}
  let!(:mock_userfile)         {mock_model(Userfile, :id => 1).as_null_object}
  let!(:data_provider)         {Factory.create(:data_provider, :user => user, :online => true, :read_only => false)}

  after(:all) do
    FileUtils.rm(Dir.glob("spec/fixtures/cbrain_test_file_*"))
  end

  context "collection action" do

    describe "index" do
      before(:each) do
        admin_userfile
        site_manager_userfile
        user_userfile
        child_userfile
        group_userfile
      end

      context "with admin user" do
        before(:each) do
          session[:user_id] = admin.id
        end

        it "should display all files if 'view all' is on" do
          get :index, "userfiles" => { "view_all" => "on" }
          assigns[:userfiles].to_a.should =~ Userfile.all
        end

        it "should only display user's files if 'view all' is off" do
          get :index, "userfiles" => { "view_all" => "off" }
          assigns[:userfiles].to_a.should =~ Userfile.all(:conditions => {:user_id => admin.id})
        end

        it "should not tree sort if tree sort not set" do
          Userfile.should_not_receive(:tree_sort)
          get :index, "userfiles" => { "tree_sort" => "off" }
        end

        it "should allow access to all files" do
          get :index, "userfiles" => { "tree_sort" => "on", "view_all" => "on" }
          assigns[:userfiles].to_a.should =~ Userfile.all
        end


        context "filtering and sorting" do
          before(:each) do
            session[:userfiles] ||= {}
            session[:userfiles]["view_all"] = "on"
            session[:userfiles]["tree_sort"] = "off"
          end

          it "should filter by type" do
            file_collection = Factory.create(:file_collection)
            get :index, "userfiles" => { "filter_hash" => {"type" => "FileCollection"} }
            assigns[:userfiles].to_a.should =~ [file_collection]
          end

          it "should filter by tag" do
            tag = Factory.create(:tag, :userfiles => [admin_userfile], :user => admin)
            get :index, "userfiles" => { "filter_tags_array" => tag.id.to_s }
            assigns[:userfiles].to_a.should =~ [admin_userfile]
          end

          it "should filter by custom filter" do
            custom_filter = UserfileCustomFilter.create(:name => "userfile_filter", :user => admin, :data => {"file_name_type"=>"match", "file_name_term" => admin_userfile.name})
            get :index, "userfiles" => { "filter_custom_filters_array" => custom_filter.id.to_s }
            assigns[:userfiles].to_a.first.should == admin_userfile
          end

          it "should filter for no parent" do
            get :index, "userfiles" => { "filter_hash" => {"has_no_parent" => "true"} }
            assigns[:userfiles].to_a.should =~ Userfile.all(:conditions => {:parent_id => nil})
          end

          it "should filter for no children" do
            get :index, "userfiles" => { "filter_hash" => {"has_no_child" => "true"} }
            assigns[:userfiles].to_a.should =~ Userfile.all(:conditions => "userfiles.id NOT IN (SELECT parent_id FROM userfiles WHERE parent_id IS NOT NULL)")
          end

          it "should sort by name" do
            get :index, "userfiles" => { "sort_hash" => {"order" => "userfiles.name"} }
            assigns[:userfiles].should == Userfile.all(:order => "userfiles.name")
          end

          it "should be able to reverse sort" do
            get :index, "userfiles" => { "sort_hash" => {"order" => "userfiles.name", "dir" => "DESC"} }
            assigns[:userfiles].should == Userfile.all(:order => "userfiles.name DESC")
          end

          it "should sort by type" do
            get :index, "userfiles" => { "sort_hash" => {"order" => "userfiles.type"} }
            assigns[:userfiles].should == Userfile.all(:order => "userfiles.type")
          end

          it "should sort by owner name" do
            get :index, "userfiles" => { "sort_hash" => {"order" => "users.login"} }
            assigns[:userfiles].should == Userfile.all(:joins => :user, :order => "users.login")
          end

          it "should sort by creation date" do
            get :index, "userfiles" => { "sort_hash" => {"order" => "userfiles.created_at"} }
            assigns[:userfiles].should == Userfile.all(:order => "userfiles.created_at")
          end

          it "should sort by size" do
            get :index, "userfiles" => { "sort_hash" => {"order" => "userfiles.size"} }
            assigns[:userfiles].should == Userfile.all(:order => "userfiles.size")
          end

          it "should sort by project name" do
            get :index, "userfiles" => { "sort_hash" => {"order" => "groups.name"} }
            assigns[:userfiles].should == Userfile.all(:joins => :group, :order => "groups.name")
          end

          it "should sort by project access" do
            get :index, "userfiles" => { "sort_hash" => {"order" => "userfiles.group_writable"} }
            assigns[:userfiles].map(&:group_writable).should == Userfile.all(:order => "userfiles.group_writable").map(&:group_writable)
          end

          it "should sort by provider" do
            get :index, "userfiles" => { "sort_hash" => {"order" => "data_providers.name"} }
            assigns[:userfiles].should == Userfile.all(:joins => :data_provider, :order => "data_providers.name")
          end
        end
      end



      context "with site manager" do
        before(:each) do
          session[:user_id] = site_manager.id
        end

        it "should display site-associated files if 'view all' is on" do
          get :index, "userfiles" => { "view_all" => "on" }
          assigns[:userfiles].to_a.should =~ Userfile.find_all_accessible_by_user(site_manager, :access_requested => :read)
        end

        it "should only display user's files if 'view all' is off" do
          get :index, "userfiles" => { "view_all" => "off" }
          assigns[:userfiles].to_a.should =~ [site_manager_userfile]
        end
      end



      context "with regular user" do
        before(:each) do
          session[:user_id] = user.id
        end

        it "should display group-associated files if 'view all' is on" do
          get :index, "userfiles" => { "view_all" => "on" }
          assigns[:userfiles].to_a.should =~ [group_userfile, user_userfile]
        end

        it "should only display user's files if 'view all' is off" do
          get :index, "userfiles" => { "view_all" => "off" }
          assigns[:userfiles].to_a.should =~ [user_userfile]
        end
      end
    end



    describe "new_parent_child" do
      before(:each) do
        session[:user_id] = admin.id
      end

      it "should render error message of no files are selected" do
        get :new_parent_child
        response.should include_text(/warning/)
      end

      it "should render the parent-child selection template" do
        get :new_parent_child, "file_ids" => [admin_userfile.id.to_s, user_userfile.id.to_s]
        response.should render_template("new_parent_child")
      end
    end



    describe "create_parent_child" do
      before(:each) do
        session[:user_id] = admin.id
      end

      it "should render an error message if no files selected" do
        post :create_parent_child, :parent_id => admin_userfile.id.to_s
        flash[:error].should include_text(/selected for this operation/)
      end

      it "should add children to parent" do
        post :create_parent_child, :child_ids => [admin_userfile.id.to_s], :parent_id => group_userfile.id.to_s
        admin_userfile.reload
        group_userfile.reload
        admin_userfile.parent.should == group_userfile
      end

      it "should redirect to index" do
        post :create_parent_child, :child_ids => [admin_userfile.id.to_s], :parent_id => group_userfile.id.to_s
        response.should redirect_to(:action => :index)
      end
    end



    describe "sync_multiple" do
      let(:mock_status) {double("status", :status => "ProvNewer")}

      before(:each) do
        session[:user_id] = admin.id
        mock_userfile.stub!(:local_sync_status).and_return(mock_status)
        Userfile.stub!(:find_accessible_by_user).and_return([mock_userfile])
        CBRAIN.stub!(:spawn_with_active_records).and_yield
      end

      it "should sync the file to the cache if it is in a valid state" do
        mock_userfile.should_receive(:sync_to_cache)
        get :sync_multiple, :file_ids => [1]
      end

      it "should not sync the file to the cache if it is not in a valid state" do
        mock_status.stub_chain(:status).and_return("InSync")
        mock_userfile.should_not_receive(:sync_to_cache)
        get :sync_multiple, :file_ids => [1]
      end
    end



    describe "create" do
      let(:mock_upload_stream) {mock_upload_file_param}

      before(:each) do
        session[:user_id] = admin.id
        Message.stub!(:send_message)
        File.stub!(:delete)
        controller.stub!(:system)
      end

      it "should redirect to index if the upload file is blank" do
        post :create
        response.should redirect_to(:action => :index)
      end

      it "should redirect to index if the upload file has an invalid name" do
        post :create, :upload_file => mock_upload_file_param(".BAD**")
        response.should redirect_to(:action => :index)
      end



      context "saving a single file" do
        before(:each) do
          CBRAIN.stub!(:spawn_with_active_records)
          SingleFile.stub!(:new).and_return(mock_userfile.as_new_record)
        end



        context "when the save fails" do
          before(:each) do
            mock_userfile.stub!(:save).and_return(false)
          end

          it "should redirect to index" do
            post :create, :upload_file => mock_upload_stream, :archive => "save"
            response.should redirect_to(:action => :index)
          end

          it "should display an error message" do
            post :create, :upload_file => mock_upload_stream, :archive => "save"
            flash[:error].should include_text(/File .+ could not be added./)
          end
        end



        context "when the save succeeds" do
          before(:each) do
            mock_userfile.stub!(:save).and_return(true)
            CBRAIN.stub!(:spawn_with_active_records).and_yield
          end

          it "should display a flash message" do
            post :create, :upload_file => mock_upload_stream, :archive => "save"
            flash[:notice].should include_text(/File .+ being added in background./)
          end



          context "when the uploaded file is available" do
            before(:each) do
              mock_upload_stream.stub!(:local_path).and_return("local_path")
            end

            it "should copy the file to the local cache" do
              mock_userfile.should_receive(:cache_copy_from_local_file)
              post :create, :upload_file => mock_upload_stream, :archive => "save"
            end
          end

          it "should save the userfile" do
            mock_userfile.should_receive(:save)
            post :create, :upload_file => mock_upload_stream, :archive => "save"
          end

          it "should update the new userfile's log" do
            mock_userfile.should_receive(:addlog_context)
            post :create, :upload_file => mock_upload_stream, :archive => "save"
          end

          it "should send a message that the upload is complete" do
            Message.should_receive(:send_message)
            post :create, :upload_file => mock_upload_stream, :archive => "save"
          end

          it "should redirect to the index" do
            post :create, :upload_file => mock_upload_stream, :archive => "save"
            response.should redirect_to(:action => :index)
          end
        end
      end



      context "extracting from an archive" do
        before(:each) do
          mock_upload_stream.stub!(:original_filename).and_return("archive.tgz")
          FileCollection.stub!(:new).and_return(mock_userfile)
        end



        context "if the file is not an archive" do
          before(:each) do
            mock_upload_stream.stub!(:original_filename).and_return("non_archive.na")
          end

          it "should redirect to the index" do
            post :create, :upload_file => mock_upload_stream, :archive => "file_collection"
            response.should redirect_to(:action => :index)
          end

          it "should display an error message" do
            post :create, :upload_file => mock_upload_stream, :archive => "file_collection"
            flash[:error].should include_text(/Error: file .+ does not have one of the supported extensions:/)
          end
        end



        context "to create a collection" do

          context "when there is a collision" do
            let(:collision_file) {Factory.create(:userfile, :name => mock_upload_stream.original_filename.split('.')[0], :user => admin )}

            it "should redirect to index" do
              post :create, :upload_file => mock_upload_stream, :archive => "file_collection", :data_provider_id => collision_file.data_provider_id
              response.should redirect_to(:action => :index)
            end

            it "should display an error message" do
              post :create, :upload_file => mock_upload_stream, :archive => "file_collection", :data_provider_id => collision_file.data_provider_id
              flash[:error].should include_text(/Collection '.+' already exists/)
            end
          end

          it "should create a FileCollection" do
            FileCollection.should_receive(:new).and_return(mock_userfile)
            post :create, :upload_file => mock_upload_stream, :archive => "file_collection"
          end



          context "when the save is successful" do
            before(:each) do
              mock_userfile.stub!(:save).and_return(true)
              CBRAIN.stub!(:spawn_with_active_records).and_yield
            end

            it "should extract the collection from the archive" do
              mock_userfile.should_receive(:extract_collection_from_archive_file)
              post :create, :upload_file => mock_upload_stream, :archive => "file_collection"
            end

            it "should send a message" do
              Message.should_receive(:send_message)
              post :create, :upload_file => mock_upload_stream, :archive => "file_collection"
            end

            it "should attempt to delete the tmp file" do
              File.should_receive(:delete)
              post :create, :upload_file => mock_upload_stream, :archive => "file_collection"
            end

            it "should display a flash message" do
              post :create, :upload_file => mock_upload_stream, :archive => "file_collection"
              flash[:notice].should include_text(/Collection '.+' created/)
            end

            it "should redirect to index" do
              post :create, :upload_file => mock_upload_stream, :archive => "file_collection"
              response.should redirect_to(:action => :index)
            end
          end



          context "when the save is unsuccessful" do
            before(:each) do
              mock_userfile.stub!(:save).and_return(false)
            end

            it "should display and error message" do
              post :create, :upload_file => mock_upload_stream, :archive => "file_collection"
              flash[:error].should include_text(/Collection '.+' could not be created/)
            end

            it "should redirect to index" do
              post :create, :upload_file => mock_upload_stream, :archive => "file_collection"
              response.should redirect_to(:action => :index)
            end
          end
        end

        it "should display an error message if the archive parameters has an invalid value" do
          post :create, :upload_file => mock_upload_stream, :archive => "invalid_parameter"
          flash[:error].should include_text(/Unknown action/)
        end



        context "to create single files" do
          before(:each) do
            CBRAIN.stub!(:spawn_with_active_records).and_yield
            controller.stub!(:extract_from_archive)
          end

          it "should extract the collection from the archive" do
            controller.should_receive(:extract_from_archive)
            post :create, :upload_file => mock_upload_stream, :archive => "extract"
          end

          it "should attempt to delete the tmp file" do
            File.should_receive(:delete)
            post :create, :upload_file => mock_upload_stream, :archive => "extract"
          end

          it "should display a flash message" do
            post :create, :upload_file => mock_upload_stream, :archive => "extract"
            flash[:notice].should include_text(/Your files are being extracted/)
          end

          it "should redirect to the index" do
            post :create, :upload_file => mock_upload_stream, :archive => "extract"
            response.should redirect_to(:action => :index)
          end
        end
      end
    end



    describe "update_multiple" do
      before(:each) do
        session[:user_id] = user.id
        Userfile.stub_chain(:find_all_accessible_by_user, :where, :all).and_return([mock_userfile])
      end

      context "when no operation is selected" do

        it "should display an error message" do
          post :update_multiple, :file_ids => [1]
          flash[:error].should include_text("Unknown operation")
        end

        it "should redirect to the index" do
          post :update_multiple, :file_ids => [1]
          response.should redirect_to(:action => :index, :format => :html)
        end
      end

      it "should update tags when requested" do
        mock_userfile.should_receive(:set_tags_for_user)
        post :update_multiple, :file_ids => [1], :update_tags => true
      end

      it "should fail to update project when user does not have access" do
        group_id_hash = {:group_id => 4}
        post :update_multiple, :file_ids => [1], :update_projects => true, :userfile => group_id_hash
        flash[:error].should include_text(/project/)
      end

      it "should update permissions when requested" do
        permission_hash = {:group_writable => true}
        mock_userfile.should_receive(:update_attributes_with_logging)
        post :update_multiple, :file_ids => [1], :update_permissions => true, :userfile => permission_hash
      end

      it "should update the file type when requested" do
        mock_userfile.should_receive(:update_file_type)
        post :update_multiple, :file_ids => [1], :update_file_type => true
      end

      it "should display the number of succesful updates" do
        mock_userfile.stub!(:send).and_return(true)
        post :update_multiple, :file_ids => [1], :update_tags => true
        flash[:notice].should include_text(" successful ")
      end

      it "should display the number of failed updates" do
        mock_userfile.stub!(:send).and_return(false)
        post :update_multiple, :file_ids => [1], :update_tags => true
        flash[:error].should include_text(" unsuccessful ")
      end

      it "should redirect to the index" do
        post :update_multiple, :file_ids => [1], :update_tags => true
        response.should redirect_to(:action => :index, :format => :html)
      end
    end



    describe "quality_control" do
      before(:each) do
        session[:user_id] = admin.id
      end

      it "should set the filelist variable" do
        filelist = ["1","2","3"]
        get :quality_control, :file_ids => filelist
        assigns[:filelist].should =~ filelist
      end
    end



    describe "quality_control_panel" do
      let(:available_tags) {double("tags").as_null_object}

      before(:each) do
        controller.stub!(:current_user).and_return(admin)
        admin.stub!(:available_tags).and_return(available_tags)
        Userfile.stub!(:find_accessible_by_user).and_return(mock_userfile)
      end

      it "should find or create a 'PASS' tag" do
        available_tags.should_receive(:find_or_create_by_name_and_user_id_and_group_id).with("QC_PASS", anything, anything)
        post :quality_control_panel
      end

      it "should find or create a 'FAIL' tag" do
        available_tags.should_receive(:find_or_create_by_name_and_user_id_and_group_id).with("QC_FAIL", anything, anything)
        post :quality_control_panel
      end

      it "should find or create an 'UNKNOWN' tag" do
        available_tags.should_receive(:find_or_create_by_name_and_user_id_and_group_id).with("QC_UNKNOWN", anything, anything)
        post :quality_control_panel
      end

      it "should update the tags if any were given" do
        mock_userfile.should_receive(:set_tags_for_user)
        post :quality_control_panel, :pass => true, :index => 1
      end

      it "should find the current file" do
        Userfile.should_receive(:find_accessible_by_user)
        post :quality_control_panel
      end

      it "should use the userfile's partial if available" do
        File.stub!(:exists?).and_return(true)
        post :quality_control_panel
        assigns[:partial].should include_text("/" + mock_userfile.class.name.underscore)
      end

      it "should use the default partial if no userfile-specific partial available" do
        File.stub!(:exists?).and_return(false)
        post :quality_control_panel
        assigns[:partial].should include_text("/default")
      end

      it "should render the quality control panel partial" do
        post :quality_control_panel
        response.should render_template("quality_control_panel")
      end
    end



    describe "create_collection" do
      before(:each) do
        controller.stub!(:current_user).and_return(admin)
        FileCollection.stub!(:new).and_return(mock_userfile)
        CBRAIN.stub!(:spawn_with_active_records).and_yield
        Userfile.stub!(:find_accessible_by_user).and_return(mock_userfile)
        DataProvider.stub!(:find_accessible_by_user).and_return([data_provider])
        Message.stub!(:send_message)
        DataProvider.stub!(:find)
      end

      it "should create a new collection" do
        FileCollection.should_receive(:new).and_return(mock_userfile)
        post :create_collection, :file_ids => [1], :data_provider_id_for_collection => data_provider.id
      end

      it "should merge the collections into a single one" do
        mock_userfile.should_receive(:merge_collections)
        post :create_collection, :file_ids => [1], :data_provider_id_for_collection => data_provider.id
      end

      it "should send a notice to the user if success happens" do
        mock_userfile.stub!(:merge_collections).and_return(:success)
        Message.should_receive(:send_message).with(anything, hash_including(:message_type  => :notice))
        post :create_collection, :file_ids => [1], :data_provider_id_for_collection => data_provider.id
      end

      it "should send an error message to the user if collision happens" do
         mock_userfile.stub!(:merge_collections).and_return(:collision)
         Message.should_receive(:send_message).with(anything, hash_including(:message_type  => :error))
         post :create_collection, :file_ids => [1], :data_provider_id_for_collection => data_provider.id
      end

      it "should send an error message to the user if exception happens" do
         mock_userfile.stub!(:merge_collections).and_raise(CbrainError)
         Message.should_receive(:send_message).with(anything, hash_including(:message_type  => :error))
         post :create_collection, :file_ids => [1], :data_provider_id_for_collection => data_provider.id
      end

      it "should display a flash message" do
        post :create_collection, :file_ids => [1], :data_provider_id_for_collection => data_provider.id
        flash[:notice].should include_text(/Collection .+ is being created in background/)
      end

      it "should redirect to the index" do
        post :create_collection, :file_ids => [1], :data_provider_id_for_collection => data_provider.id
        response.should redirect_to(:action => :index, :format => :html)
      end
    end



    describe "change_provider" do
      before(:each) do
        controller.stub!(:current_user).and_return(admin)
         admin.stub!(:license_agreement_set).and_return([])
         admin.stub!(:unsigned_license_agreements).and_return([])
        DataProvider.stub_chain(:find_all_accessible_by_user, :where, :first).and_return(mock_model(DataProvider).as_null_object)
        CBRAIN.stub!(:spawn_with_active_records).and_yield
        Userfile.stub!(:find_accessible_by_user).and_return(mock_userfile)
        mock_userfile.stub!(:provider_move_to_otherprovider)
        mock_userfile.stub!(:provider_copy_to_otherprovider)

      end

      context "when the other data povider is not found" do
        before(:each) do
          DataProvider.stub_chain(:find_all_accessible_by_user, :where, :first).and_return(nil)
        end

        it "should display an error message" do
          post :change_provider, :file_ids => [1], :data_provider_id_for_mv_cp => data_provider.id
          flash[:error].should include_text(/Data provider .* not accessible/)
        end

        it "should redirect to the index" do
          post :change_provider, :file_ids => [1]
          response.should redirect_to(:action => :index, :format => :html)
        end
      end

      context "when moving a file" do

        it "should check if the user has owner access" do
          mock_userfile.should_receive(:has_owner_access?)
          post :change_provider, :file_ids => [1], :move => true, :data_provider_id_for_mv_cp => data_provider.id
        end

        it "should attempt to move the file if the user has owner access" do
          mock_userfile.stub!(:has_owner_access?).and_return(true)
          mock_userfile.should_receive(:provider_move_to_otherprovider)
          post :change_provider, :file_ids => [1], :move => true, :data_provider_id_for_mv_cp => data_provider.id
        end

        it "should not attempt to move the file if the user does not have owner access" do
          mock_userfile.stub!(:has_owner_access?).and_return(false)
          mock_userfile.should_not_receive(:provider_move_to_otherprovider)
          post :change_provider, :file_ids => [1], :move => true, :data_provider_id_for_mv_cp => data_provider.id
        end
      end

      it "should attempt to copy the file when requested" do
        mock_userfile.should_receive(:provider_copy_to_otherprovider)
        post :change_provider, :file_ids => [1], :copy => true, :data_provider_id_for_mv_cp => data_provider.id
      end

      it "should send message about successes" do
        mock_userfile.stub!(:provider_copy_to_otherprovider).and_return(true)
        Message.should_receive(:send_message).with(anything, hash_including(:message_type  => :notice))
        post :change_provider, :file_ids => [1], :copy => true, :data_provider_id_for_mv_cp => data_provider.id
      end

      it "should send message about failures" do
        mock_userfile.stub!(:provider_copy_to_otherprovider).and_return(false)
        Message.should_receive(:send_message).with(anything, hash_including(:message_type  => :error))
        post :change_provider, :file_ids => [1], :copy => true, :data_provider_id_for_mv_cp => data_provider.id
      end

      it "should display a flash message" do
        post :change_provider, :file_ids => [1], :data_provider_id_for_mv_cp => data_provider.id
        flash[:notice].should include_text(/Your files are being .+ in the background/)
      end

      it "should redirect to the index" do
        post :change_provider, :file_ids => [1]
        response.should redirect_to(:action => :index, :format => :html)
      end
    end



    describe "manage_persistent" do
      let(:current_session) {double("current_session", :persistent_userfile_ids_list => [1]).as_null_object}

      before(:each) do
        controller.stub!(:current_user).and_return(admin)
        controller.stub!(:current_session).and_return(current_session)
      end

      it "should clear the persistent ids if the operation is 'clear'" do
        current_session.should_receive(:persistent_userfile_ids_clear).and_return(1)
        post :manage_persistent, :file_ids => [1], :operation => "clear"
      end

      it "should clear and then add the persistent ids if the operation is 'replace'" do
        current_session.should_receive(:persistent_userfile_ids_clear).ordered.and_return(1)
        current_session.should_receive(:persistent_userfile_ids_add).ordered.and_return(1)
        post :manage_persistent, :file_ids => [1], :operation => "replace"
      end

      it "should add the persistent ids if the operation is 'add'" do
        current_session.should_receive(:persistent_userfile_ids_add).ordered.and_return(1)
        post :manage_persistent, :file_ids => [1], :operation => "add"
      end

      it "should remove the persistent ids if the operation is 'remove'" do
        current_session.should_receive(:persistent_userfile_ids_remove).ordered.and_return(1)
        post :manage_persistent, :file_ids => [1], :operation => "remove"
      end

      it "should display a report if the persistent file ids changed" do
        current_session.stub!(:persistent_userfile_ids_list).and_return([1])
        post :manage_persistent, :file_ids => [1], :operation => "remove"
        flash[:notice].should include_text(/Total of .* now in the persistent list of files/)
      end

      it "should display a message saying no file ids were changed if that is the case" do
        current_session.stub!(:persistent_userfile_ids_remove).and_return(0)
        post :manage_persistent, :file_ids => [1], :operation => "remove"
        flash[:notice].should include_text("No changes made to the persistent list of userfiles")
      end

      it "should redirect to the index" do
        post :manage_persistent, :file_ids => [1], :operation => "remove"
        response.should redirect_to(:action => :index)
      end
    end



    describe "delete_files" do
      before(:each) do
        controller.stub!(:current_user).and_return(admin)
        mock_userfile.stub!(:id).and_return(1)
        Userfile.stub_chain(:accessible_for_user, :where).and_return([mock_userfile])
        CBRAIN.stub!(:spawn_with_active_records).and_yield
      end

      it "should display error message if userfiles is not accessible by user" do
        Userfile.stub_chain(:accessible_for_user, :where).and_return([])
        delete :delete_files, :file_ids => [1]
        flash[:error].should include_text("not have acces")
      end

      it "should destroy the userfiles" do
        mock_userfile.should_receive(:destroy)
        delete :delete_files, :file_ids => [1]
      end

      it "should announce that files are being deleted in the background" do
        mock_userfile.stub_chain(:data_provider, :is_browsable?).and_return(false)
        mock_userfile.stub_chain(:data_provider, :meta, :[], :blank?).and_return(false)
        delete :delete_files, :file_ids => [1]
        flash[:notice].should include_text("deleted in background")
      end

      it "should redirect to the index" do
        delete :delete_files, :file_ids => [1]
        response.should redirect_to(:action => :index)
      end
    end



    describe "download" do
      before(:each) do
        controller.stub!(:current_user).and_return(admin)
        controller.stub!(:send_file)
        controller.stub!(:sleep)
        controller.stub!(:render)
        Userfile.stub!(:find_accessible_by_user).and_return([mock_userfile])
        mock_userfile.stub!(:size).and_return(5)
        CBRAIN.stub!(:spawn_fully_independent)
      end

      context "when an illegal file name is given" do
        before(:each) do
          Userfile.stub!(:is_legal_filename?).and_return(false)
        end

        it "should display an error message" do
          get :download, :file_ids => [1], :specified_filename => "not_valid"
          flash[:error].should include_text(/filename '.+' is not acceptable/)
        end

        it "should redirect to the index" do
          get :download, :file_ids => [1], :specified_filename => "not_valid"
          response.should redirect_to(:action => :index, :format => :html)
        end
      end

      it "should find the userfiles" do
        Userfile.should_receive(:find_accessible_by_user).and_return([mock_userfile])
        get :download, :file_ids => [1]
      end



      context "when the max download size is exceeded" do
        before(:each) do
          mock_userfile.stub!(:size).and_return(UserfilesController::MAX_DOWNLOAD_MEGABYTES.megabytes + 1)
        end

        it "should display an error message" do
          get :download, :file_ids => [1]
          flash[:error].should include_text("You cannot download data that exceeds")
        end

        it "should redirect to the index" do
          get :download, :file_ids => [1]
          response.should redirect_to(:action => :index, :format => :html)
        end
      end

      it "should sync the files to the cache" do
        mock_userfile.should_receive(:sync_to_cache)
        get :download, :file_ids => [1]
      end

      it "should send the file if it is one SingleFile" do
        mock_userfile.stub!(:is_a?).and_return(true)
        controller.should_receive(:send_file)
        get :download, :file_ids => [1]
      end

      it "should create a tar for multiple files" do
        controller.should_receive(:create_relocatable_tar_for_userfiles)
        get :download, :file_ids => [1]
      end

      it "should send the tar file for multiple files" do
        controller.should_receive(:send_file)
        get :download, :file_ids => [1]
      end

      it "should delete the tar file" do
        CBRAIN.stub!(:spawn_fully_independent).and_yield
        File.should_receive(:unlink)
        get :download, :file_ids => [1]
      end
    end



    describe "compress" do
      let(:mock_singlefile) {mock_model(SingleFile, :name => "file_name").as_null_object}

      before(:each) do
        controller.stub!(:current_user).and_return(admin)
        Userfile.stub!(:find_accessible_by_user).and_return([mock_singlefile])
        mock_singlefile.stub_chain(:data_provider, :read_only?).and_return(false)
        Userfile.stub_chain(:where, :first).and_return(nil)
        CBRAIN.stub!(:spawn_with_active_records)
      end

      it "should display an error message if the file is not a SingleFile" do
        Userfile.stub!(:find_accessible_by_user).and_return([mock_userfile])
        post :compress, :file_ids => [1]
        flash[:error].should include_text("Not a SingleFile")
      end

      it "should display an error message if the data provider is not writable" do
        mock_singlefile.stub_chain(:data_provider, :read_only?).and_return(true)
        post :compress, :file_ids => [1]
        flash[:error].should include_text("Data Provider not writable")
      end

      it "should display an error message file name already exists" do
        Userfile.stub_chain(:where, :exists?).and_return(true)
        post :compress, :file_ids => [1]
        flash[:error].should include_text("Filename collision")
      end



      context "when compressing" do
        before(:each) do
          Userfile.stub_chain(:where, :exists?).and_return(false)
          CBRAIN.stub!(:spawn_with_active_records).and_yield
          SyncStatus.stub!(:ready_to_modify_cache).and_yield
          controller.stub!(:system)
          File.stub!(:rename)
          Message.stub!(:send_message)
        end

        it "should rename the file on the provider" do
          mock_singlefile.should_receive(:provider_rename)
          post :compress, :file_ids => [mock_singlefile.id]
        end

        it "should sync the file to the cache" do
          mock_singlefile.should_receive(:sync_to_cache)
          post :compress, :file_ids => [1]
        end

        it "should ensure that the cache is ready to be modified" do
          SyncStatus.should_receive(:ready_to_modify_cache)
          post :compress, :file_ids => [1]
        end

        it "should compress the file if it is uncompressed" do
          controller.should_receive(:system).with(/^gzip/)
          post :compress, :file_ids => [1]
        end

        it "should uncompress the file if it is compressed" do
          mock_singlefile.stub!(:name).and_return("file_name.gz")
          controller.should_receive(:system).with(/^gunzip/)
          post :compress, :file_ids => [1]
        end

        it "should crush the original file" do
          File.should_receive(:rename)
          post :compress, :file_ids => [1]
        end

        it "should sync the file to the provider" do
          mock_singlefile.should_receive(:sync_to_provider)
          post :compress, :file_ids => [1]
        end

        it "should send a message to the user" do
          Message.should_receive(:send_message)
          post :compress, :file_ids => [1]
        end
      end

      it "should redirect to the index" do
        Userfile.stub_chain(:where, :exists?).and_return(true)
        post :compress, :file_ids => [1]
        response.should redirect_to(:action => :index, :format => :html)
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
        Userfile.stub!(:find_accessible_by_user).and_return(mock_userfile)
        mock_userfile.stub!(:find_content_loader).and_return(content_loader)
        mock_userfile.stub!(:content_loader_method)
        controller.stub!(:send_file)
        controller.stub!(:render)
      end

      it "should determine if the userfile has a content loader" do
        mock_userfile.should_receive(:find_content_loader).and_return(nil)
        get :content, :id => 1
      end

      it "should send file given by the content loader for a send_file loader" do
        content_loader.stub!(:type).and_return(:send_file)
        mock_userfile.stub!(:content_loader_method).and_return("path")
        controller.should_receive(:send_file).with("path")
        get :content, :id => 1
      end

      it "should send zipped data given by the content method" do
        content_loader.stub!(:type).and_return(:gzip)
        get :content, :id => 1
        response.headers["Content-Encoding"].should == "gzip"
      end

      it "should render any other content defined by the content loader" do
        type    = :text
        content = "content"
        content_loader.stub!(:type).and_return(type)
        mock_userfile.stub!(:content_loader_method).and_return(content)
        controller.should_receive(:render).with(type => content)
        get :content, :id => 1
      end

      it "should send the userfile itself if no content given" do
        mock_userfile.stub!(:find_content_loader).and_return(nil)
        mock_userfile.stub!(:cache_full_path).and_return("path")
        controller.should_receive(:send_file).with("path", anything)
        get :content, :id => 1
      end
    end



    describe "display" do
      let(:mock_viewer) {double(Userfile::Viewer, :partial => "partial").as_null_object}

      before(:each) do
        mock_userfile.stub!(:find_viewer).and_return(mock_viewer)
        Userfile.stub!(:find_accessible_by_user).and_return(mock_userfile)
        File.stub!(:exists).and_return(true)
      end

      it "should get the partial from the userfile's viewer if it exists" do
        mock_viewer.should_receive(:partial)
        get :display, :id => 1
      end

      it "should try find a partial with the viewer name if the userfile doesn't have an associated viewer" do
        mock_userfile.stub!(:find_viewer).and_return(nil)
        File.should_receive(:exists?).and_return(true)
        get :display, :id => 1, :viewer => "hello"
      end

      it "should render the viewer partial if no div is requested" do
        controller.stub!(:render)
        controller.should_receive(:render).with(hash_including(:partial => "userfiles/viewers/#{mock_viewer.partial}"))
        get :display, :id => 1, :apply_div => "false"
      end

      it "should render the display partial a div is requested" do
        get :display, :id => 1
        response.should render_template("display")
      end

      it "should render a warning if no viewer partial is found" do
        mock_viewer.stub!(:partial).and_return(nil)
        get :display, :id => 1
        response.should include_text(/Could not find viewer/)
      end
    end



    describe "show" do
      let(:mock_status) {double("status", :status => "ProvNewer")}

      before(:each) do
        Userfile.stub!(:find_accessible_by_user).and_return(mock_userfile)
        mock_userfile.stub!(:local_sync_status).and_return(mock_status)
      end

      it "should find the requested userfile" do
        Userfile.should_receive(:find_accessible_by_user).and_return(mock_userfile)
        get :show, :id => 1
      end

      it "should retreive the sync status" do
        mock_status.stub!(:status).and_return("userfile_status")
        get :show, :id => 1
        assigns[:sync_status].should == "userfile_status"
      end

      it "should set the sync status to 'Prov Newer' if it isn't set yet" do
        mock_userfile.stub!(:local_sync_status).and_return(nil)
        get :show, :id => 1
        assigns[:sync_status].should == "ProvNewer"
      end

      it "should retreive the default viewer" do
        mock_userfile.stub_chain(:viewers, :first).and_return("default_viewer")
        get :show, :id => 1
        assigns[:default_viewer].should == "default_viewer"
      end

      it "should retreive the userfile's log" do
        mock_userfile.stub!(:getlog).and_return("userfile_log")
        get :show, :id => 1
        assigns[:log].should == "userfile_log"
      end

      it "should set the log to nil if an error occurs" do
        mock_userfile.stub!(:getlog).and_raise(StandardError)
        get :show, :id => 1
        assigns[:log].should be_nil
      end

      it "should render the show page" do
        get :show, :id => 1
        response.should render_template("show")
      end
    end

    describe "update" do
      before(:each) do
        Userfile.stub!(:find_accessible_by_user).and_return(mock_userfile)
        Userfile.stub!(:is_legal_filename?).and_return(true)
      end

      it "should find the requested file" do
        Userfile.should_receive(:find_accessible_by_user).and_return(mock_userfile)
        put :update, :id => 1
      end

      it "it should display an error message when attempting to update to an invalid type" do
        mock_userfile.stub!(:update_file_type).and_return(nil)
        put :update, :id => 1, :file_type => "InvalidType"
        mock_userfile.errors[:type].first.should be =~  /could not be/
      end

      it "should set tags" do
        mock_userfile.should_receive(:set_tags_for_user)
        put :update, :id => 1
      end

      it "should update attributes" do
        mock_userfile.should_receive(:save_with_logging)
        put :update, :id => 1
      end

      context "when the update is successful" do
        before(:each) do
          mock_userfile.stub!(:update_attributes).and_return(true)
        end



        context "and the name is changed" do
          before(:each) do
            mock_userfile.stub!(:name).and_return("old_name")
            mock_userfile.stub!(:provider_rename).and_return(true)
          end

          it "should attempt to rename the file on the provider" do
            mock_userfile.should_receive(:provider_rename)
            put :update, :id => 1, :userfile => {:name => "new_name"}
          end

          it "should not save if the provider rename was not successful" do
            mock_userfile.stub!(:provider_rename).and_return(false)
            mock_userfile.should_not_receive(:save)
            put :update, :id => 1, :userfile => {:name => "new_name"}
          end
        end

        it "should display a flash message" do
          put :update, :id => 1
          flash[:notice].should include_text("successfully updated")
        end

        it "should redirect to the show page" do
          put :update, :id => 1
          response.should redirect_to(:action => :show)
        end
      end



      context "when the update is unsuccesful" do

        it "should render the show action" do
          mock_userfile.stub!(:errors).and_return({:type => "Some errors"})
          put :update, :id => 1
          response.should render_template(:show)
        end
      end
    end


    describe "extract_from_collection" do
      let(:mock_collection) {mock_model(FileCollection).as_null_object}

      before(:each) do
        FileCollection.stub!(:find_accessible_by_user).and_return(mock_collection)
        SingleFile.stub!(:new).and_return(mock_userfile)
        Dir.stub!(:chdir).and_yield
      end



      context "when no files are selected" do

        it "should display a flash message" do
          post :extract_from_collection, :id => 1
          flash[:notice].should include_text("No files selected for extraction")
        end

        it "should redirect to the edit page" do
          post :extract_from_collection, :id => 1
          response.should redirect_to(:action => :show, :id => 1)
        end
      end

      it "should find the collection" do
         FileCollection.should_receive(:find_accessible_by_user).and_return(mock_collection)
         post :extract_from_collection, :id => 1, :file_names => ["file_name"]
      end

      it "should create a new single file" do
        SingleFile.should_receive(:new).and_return(mock_userfile)
        post :extract_from_collection, :id => 1, :file_names => ["file_name"]
      end

      it "should save the new file" do
        mock_userfile.should_receive(:save).and_return(true)
        post :extract_from_collection, :id => 1, :file_names => ["file_name"]
      end



      context "when the save is successful" do
        before(:each) do
          mock_userfile.stub!(:save).and_return(true)
        end

        it "should copy the file to the cache" do
          mock_userfile.should_receive(:cache_copy_from_local_file)
          post :extract_from_collection, :id => 1, :file_names => ["file_name"]
        end

        it "should display a flash message" do
          post :extract_from_collection, :id => 1, :file_names => ["file_name"]
          flash[:notice].should include_text("successfuly extracted")
        end
      end



      context "when the save is unsuccessful" do
        before(:each) do
          mock_userfile.stub!(:save).and_return(false)
        end

        it "should not attempt to copy the file to the cache"do
          mock_userfile.should_not_receive(:cache_copy_from_local_file)
          post :extract_from_collection, :id => 1, :file_names => ["file_name"]
        end

        it "should display an error message" do
          post :extract_from_collection, :id => 1, :file_names => ["file_name"]
          flash[:error].should include_text("could not be extracted")
        end
      end

      it "should redirect to the index" do
        post :extract_from_collection, :id => 1, :file_names => ["file_name"]
        response.should redirect_to(:action => :index)
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

    describe "update" do

      it "should redirect the login page" do
        put :update, :id => 1
        response.should redirect_to(:controller => :sessions, :action => :new)
      end
    end
  end

end

