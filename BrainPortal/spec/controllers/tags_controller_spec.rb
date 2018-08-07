
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
  let(:params)       { { :tag => { :user_id => current_user.id, :group_id => current_user.own_group.id } } }

  context "with a logged in user" do
    before(:each) do
      session[:user_id]    = current_user.id
      session[:session_id] = 'session_id'
    end

    describe "create" do
      it "should assign the tag to the current user" do
        post :create, params: params, xhr: true
        expect(assigns[:tag].user_id).to eq(current_user.id)
      end
      it "should assign the tag to the own group of the current user" do
        post :create, params: params, xhr: true
        expect(assigns[:tag].group_id).to eq(current_user.own_group.id)
      end
      it "should save the record" do
        allow(Tag).to  receive(:new).and_return(tag)
        expect(tag).to receive(:save)
        post :create, params: params, xhr: true
      end

      context "when save is successful" do
        before(:each) do
          allow(Tag).to receive(:new).and_return(tag)
          allow(tag).to receive(:save).and_return(true)
        end

        it "should display a flash message" do
          post :create, params: params, xhr: true
          expect(flash[:notice]).to eq('Tag was successfully created.')
        end
      end

      context "when save is unsuccessful" do
        before(:each) do
          allow(Tag).to receive(:new).and_return(tag)
          allow(tag).to receive(:save).and_return(false)
        end

        it "should return :unprocessable_entity status in xml" do
          params[:format] = "xml"
          post :create, params: params
          expect(response.status).to eq(Rack::Utils::SYMBOL_TO_STATUS_CODE[:unprocessable_entity])
        end
      end
    end

    describe "update" do
      let(:real_tag) { create(:tag, :name => "name", :user_id => current_user.id) }

      before(:each) do
        params[:id] = real_tag.id
      end

      it "should find the requested tag" do
        params[:id] = real_tag.id
        put :update, params: params, xhr: true
        expect(assigns[:tag]).to eq(real_tag)
      end

      context "when update is successful" do
        it "should display a flash message" do
          put :update, params: params, xhr: true
          expect(flash[:notice]).to eq("Tag was successfully updated.")
        end
      end

      context "when update fails" do
        it "should return :unprocessable_entity status in xml" do
          params[:tag][:name]   = "#"
          params[:format]       = "xml"
          put :update, params: params
          expect(response.status).to eq(Rack::Utils::SYMBOL_TO_STATUS_CODE[:unprocessable_entity])
        end
      end
    end

    describe "destroy" do
      let!(:real_tag) { create(:tag, :user_id => current_user.id)}

      it "should find the requested tag" do
        delete :destroy, params: {id: real_tag.id}, xhr: true
        expect(assigns[:tag]).to eq(real_tag)
      end
      it "should call destroy on requested_tag" do
        expect {
          delete :destroy, params: {id: real_tag.id} , xhr: true}
        .to change(Tag, :count).by(-1)
      end
    end
  end


  context "when the user is not logged in" do

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

