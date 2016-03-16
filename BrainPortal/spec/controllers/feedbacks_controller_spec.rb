
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

RSpec.describe FeedbacksController, :type => :controller do
  let(:feedback)     { mock_model(Feedback).as_null_object }
  let(:current_user) { create(:normal_user) }

  context "with a logged in user" do
    before(:each) do
      session[:user_id] = current_user.id
    end

    context "collection action" do
      describe "index" do
        let!(:fb) { create(:feedback) }
        it "should assign @feedbacks" do
          get :index
          expect(assigns[:feedbacks]).to eq([fb])
        end
        it "should render the index page" do
         get :index
         expect(response).to render_template("index")
        end
      end
      describe "create" do
        before(:each) do
          allow(Feedback).to receive(:new).and_return(feedback)
          allow(Message).to  receive(:send_message)
        end
        it "should create a new feedback object with given params" do
          expect(Feedback).to receive(:new).with("summary" => "summary", "details" => "details")
          post :create, :feedback => { :summary => "summary", :details => "details" }
        end
        it "should assign the feedback to the current user" do
          expect(feedback).to receive(:user_id=).with(current_user.id)
          post :create
        end
        it "should save the record" do
          expect(feedback).to receive(:save)
          post :create
        end
        context "when save is successful" do
          before(:each) do
            allow(feedback).to receive(:save).and_return(true)
          end
          it "should display a flash message" do
            post :create
            expect(flash[:notice]).to eq("Feedback was successfully created.")
          end
          it "should send a message to admin" do
            expect(Message).to receive(:send_message)
            post :create
          end
          it "should redirect to the index" do
            post :create, :format => "js"
            expect(response).to redirect_to(:action => :index, :format => :js)
          end
        end
        context "when save is unsuccesful" do
          before(:each) do
            allow(feedback).to receive(:save).and_return(false)
          end
          it "should not send a message to admin" do
            expect(Message).not_to receive(:send_message)
            post :create
          end
          it "should render the failed create partial" do
            post :create, :format => "js"
            expect(response).to render_template("shared/_failed_create")
          end
        end
      end
    end
    context "member action" do
      before(:each) do
        allow(Feedback).to receive(:find).and_return(feedback)
      end
      describe "show" do
        it "should find the requested record" do
          expect(Feedback).to receive(:find).with(feedback.id.to_s)
          get :show, :id => feedback.id
        end
        it "should render the show page" do
          get :show, :id => feedback.id
          expect(response).to render_template("show")
        end
      end
      describe "update" do
        it "should find the requested record" do
          expect(Feedback).to receive(:find).with(feedback.id.to_s)
          put :update, :id => feedback.id
        end
        it "should update the record" do
          expect(feedback).to receive(:update_attributes_with_logging)
          put :update, :id => feedback.id, :feedback => { :summary => "summary", :details => "details" }
        end
        context "when update is successful" do
          before(:each) do
            allow(feedback).to receive(:update_attributes).and_return(true)
          end
          it "should display a flash message" do
            put :update, :id => feedback.id
            expect(flash[:notice]).to eq("Feedback was successfully updated.")
          end
          it "should redirect to the index" do
            put :update, :id => feedback.id
            expect(response).to redirect_to(:action => "show")
          end
        end
      end
      describe "destroy" do
        it "should find the requested record" do
          expect(Feedback).to receive(:find).with(feedback.id.to_s)
          delete :destroy, :id => feedback.id
        end
        it "should destroy the record" do
          expect(feedback).to receive(:destroy)
          delete :destroy, :id => feedback.id
        end
        it "should redirect to index for an html request" do
          delete :destroy, :id => feedback.id, :format => "html"
          expect(response).to redirect_to(:action => :index)
        end
        it "should redirect to the index" do
          delete :destroy, :id => feedback.id, :format => "js"
          expect(response).to redirect_to(:action => :index, :format => :js)
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
  end

end

