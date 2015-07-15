
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

RSpec.describe TagsController, :type => :controller do
  let(:tag)          { mock_model(Tag).as_null_object }
  let(:current_user) { create(:normal_user) }

  context "with a logged in user" do
    before(:each) do
      session[:user_id] = current_user.id
    end

    describe "new" do
      before(:each) do
        allow(Tag).to receive(:new).and_return(tag)
      end

      it "should assign @tag" do
        get :new
        expect(assigns[:tag]).to eq(tag)
      end
      it "should creates a new object" do
        expect(Tag).to receive(:new).with(:group_id => current_user.own_group.id)
        get :new
      end
    end

    describe "edit" do
      let(:real_tag) {create(:tag, :user_id => current_user.id)}

      it "should find the requested tag" do
        get :edit, :id => real_tag.id
        expect(assigns[:tag]).to eq(real_tag)
      end
      it "should render the edit page" do
        get :edit, :id => real_tag.id
        expect(response).to render_template("edit")
      end
    end

    describe "create" do
      before(:each) do
        allow(Tag).to receive(:new).and_return(tag)
      end

      it "should create a new tag object with given params" do
        expect(Tag).to receive(:new).with("name" => "name", "user_id" => current_user.id.to_s)
        post :create, :tag => { :name => "name", :user_id => current_user.id.to_s}
      end
      it "should assign the tag to the current user" do
        expect(tag).to receive(:user_id=).with(current_user.id)
        post :create
      end
      it "should save the record" do
        expect(tag).to receive(:save)
        post :create
      end
      it "should render the create page" do
          post :create, :format => "js"
          expect(response).to render_template("create")
      end

      context "when save is successful" do
        before(:each) do
          allow(tag).to receive(:save).and_return(true)
        end

        it "should display a flash message" do
          post :create
          expect(flash[:notice]).to eq('Tag was successfully created.')
        end
        it "should redirect to the index" do
          post :create
          expect(response).to redirect_to(:action => :index, :controller => :userfiles)
        end
      end

      context "when save is unsuccesful" do
        before(:each) do
          allow(tag).to receive(:save).and_return(false)
        end

        it "should render the edit page" do
          post :create
          expect(response).to redirect_to(:action => :index, :controller => :userfiles)
        end
      end
    end

    describe "update" do
      let(:real_tag) { create(:tag, :name => "name", :user_id => current_user.id) }

      it "should find the requested tag" do
        put :update, :id => real_tag.id
        expect(assigns[:tag]).to eq(real_tag)
      end
      it "should render the create page when js is requested" do
        put :update, :id => real_tag.id,  :format => "js"
        expect(response).to render_template(:action => "update")
      end

      context "when update is successful" do
        it "should display a flash message" do
          put :update, :id => real_tag.id
          expect(flash[:notice]).to eq("Tag was successfully updated.")
        end
        it "should redirect to the userfile index page" do
          put :update, :id => real_tag.id
          expect(response).to redirect_to(:action => :index, :controller => :userfiles)
        end
      end

      context "when update fails" do
        it "should render the edit page" do
          put :update, :id => real_tag.id.to_s,:tag => {"name" => '#' }
          expect(response).to render_template("edit")
        end
      end
    end

    describe "destroy" do
      let(:real_tag) { create(:tag, :user_id => current_user.id)}
      before(:each) do
        session[:userfiles] ||= {}
      end

      it "should find the requested tag" do
        delete :destroy, :id => real_tag.id
        expect(assigns[:tag]).to eq(real_tag)
      end

      it "should call delete on session[:userfiles][filter_tags_array]" do
        session[:userfiles]["filter_tags_array"] = [real_tag.id.to_s]
        expect(session[:userfiles]["filter_tags_array"]).to receive(:delete)
        delete :destroy, :id => real_tag.id.to_s
      end

      it "should redirect to index for an html request" do
        delete :destroy, :id => real_tag.id.to_s, :format => "html"
        expect(response).to redirect_to(:action => :index, :controller => :userfiles)
      end
      it "should render the update_tag_table js script for a script request" do
        delete :destroy, :id => real_tag.id, :format => "js"
        expect(response).to render_template("tags/_update_tag_table")
      end
    end
  end


  context "when the user is not logged in" do

    describe "edit" do
      it "should redirect the login page" do
        get :edit, :id => 1
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
  end
end

