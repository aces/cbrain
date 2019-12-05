
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

RSpec.describe AccessProfilesController, :type => :controller do

  #==========================================
  # Admin User
  #==========================================

  context "with an admin user" do

    let(:current_user) { create(:admin_user) }

    # User 'A', Group 'A' and AP 'A' all link together
    let(:user_a)  { create(:normal_user_with_assocs,    :login => "U_A") }
    let(:group_a) { create(:work_group_with_assocs,     :name  => "G_A", :users => [ user_a ] ) }
    let(:ap_a)    { create(:access_profile_with_assocs,
                              :name  => "AP_A",
                              :users => [ user_a ],
                              :groups => [ group_a ]
                           )
                  }

    # User 'B' is in no group; Group 'B' has no users, AP 'B' has no groups
    let(:user_b)  { create(:normal_user_with_assocs,    :login => "U_B") }
    let(:group_b) { create(:work_group_with_assocs,     :name  => "G_B") }
    let(:ap_b)    { create(:access_profile_with_assocs, :name  => "AP_B") }

    # Group O has user 'B'
    let(:group_o) { create(:work_group_with_assocs,     :name  => "G_Oth", :users  => [ user_b ] ) }

    # AP 'AB' has group 'A' and 'B' and no users
    let(:ap_ab)   { create(:access_profile_with_assocs,
                              :name      => "AP_AB",
                              :groups => [ group_a, group_b ],
                              :users  => [ ],
                          )
                  }

    fake_ap = FactoryBot.attributes_for(:access_profile)

    before(:each) do
      allow(controller).to receive(:current_user).and_return(current_user)
      session[:session_id] = 'session_id'
    end

    #----------------
    # INDEX
    #----------------
    describe "index" do
      it "should return all access_profiles" do
        ap_a ; ap_b ; ap_ab
        get :index
        expect(assigns[:access_profiles].to_a).to match_array(AccessProfile.all.to_a)
        expect(assigns[:access_profiles].size).to eq(3)
      end
    end

    #----------------
    # SHOW
    #----------------
    describe "show" do
      it "should return a profile by ID" do
        get :show, params: {:id => ap_b.id}
        expect(assigns[:access_profile]).to match(ap_b)
      end
      it "should fail on a unknown profile ID" do
        get :show, params: {:id => -987}
        expect(flash[:error]).to eq(ExceptionHelpers::NOT_FOUND_MSG)
      end
    end

    #----------------
    # NEW
    #----------------
    describe "new" do
      it "should initialize a new access profile" do
        get :new
        expect(assigns[:access_profile]).to be_a_new(AccessProfile)
      end
    end

    #----------------
    # CREATE
    #----------------
    describe "create" do
      it "should create a new access profile" do
        attributes =  { :name => "Abc",
                        :description => "Desc1",
                        :user_ids    => [ user_a.id, user_b.id ],
                        :group_ids   => [ group_a.id, group_b.id ],
                      }
        post :create, params: {:access_profile => attributes}
        expect(assigns[:access_profile]).to     match(AccessProfile.last)
        expect(AccessProfile.last.user_ids).to  match_array(attributes[:user_ids])
        expect(AccessProfile.last.group_ids).to match_array(attributes[:group_ids])
      end
    end

    #----------------
    # UPDATE
    #----------------
    describe "update" do
      it "should find a profile by ID" do
        post :update, params: {:id => ap_b.id, :access_profile => fake_ap }
        expect(assigns[:access_profile]).to match(ap_b)
      end
      it "should fail on a unknown profile ID" do
        post :update, params: {:id => -987}
        expect(flash[:error]).to eq(ExceptionHelpers::NOT_FOUND_MSG)
      end
      it "should change standard attributes" do
        new_att = { :name => 'new_name', :description => 'new_desc', :color => '#cababe' }
        post :update, params: {:id => ap_b.id, :access_profile => new_att}
        updated_ap = AccessProfile.find(ap_b.id)
        expect(updated_ap.name).to        match(new_att[:name])
        expect(updated_ap.description).to match(new_att[:description])
        expect(updated_ap.color).to       match(new_att[:color])
      end
      context "when a group is added" do
        it "should adjust all affected users" do
          post :update, params: {
                        :id                => ap_a.id,
                        :affected_user_ids => [ user_a.id ],
                        :access_profile    =>
                          ap_a.attributes.slice("name","description","color")
                          .merge(:user_ids => [ user_a.id ], :group_ids => [ group_a.id, group_o.id ])
                        }
          ap_a.reload
          expect(ap_a.group_ids).to match_array([ group_a.id, group_o.id ])

          user_a.reload
          expect(user_a.group_ids).to match_array([ Group.everyone.id, user_a.own_group.id, group_a.id, group_o.id ])
        end
      end
      context "when a group is removed" do
        it "should adjust all affected users" do
          post :update, params: {
                        :id                => ap_a.id,
                        :affected_user_ids => [ user_a.id ],
                        :access_profile    =>
                          ap_a.attributes.slice("name","description","color")
                          .merge(:user_ids => [ user_a.id ], :group_ids => [ "" ])
                        }
          ap_a.reload
          expect(ap_a.group_ids).to match_array([ ])

          user_a.reload
          expect(user_a.group_ids).to match_array([ Group.everyone.id, user_a.own_group.id ])
        end
      end
      context "when a user is added" do
        it "should adjust the user's group list" do  # add user B to AP A
          post :update, params: {
                        :id                => ap_a.id,
                        :access_profile    =>
                          ap_a.attributes.slice("name","description","color")
                          .merge(:user_ids => [ user_a.id, user_b.id ])
                        }
          ap_a.reload
          expect(ap_a.user_ids).to match_array([ user_a.id, user_b.id ])

          user_b.reload
          expect(user_b.group_ids).to match_array([ Group.everyone.id, user_b.own_group.id, group_a.id ])
        end
      end
      context "when a user is removed" do
        it "should adjust the user's group list" do  # remove user A from AP A
          post :update, params: {
                        :id                => ap_a.id,
                        :access_profile    =>
                          ap_a.attributes.slice("name","description","color")
                          .merge(:user_ids => [ "" ], :group_ids => [ group_a.id ])
                        }
          ap_a.reload
          expect(ap_a.user_ids).to match_array([ ])

          user_a.reload
          expect(user_a.group_ids).to match_array([ Group.everyone.id, user_a.own_group.id ])
        end
      end
    end

    #----------------
    # DESTROY
    #----------------
    describe "destroy" do
      it "should destroy the access profile" do
        post :destroy, params: {:id => ap_a.id}
        expect(AccessProfile.where(:id => ap_a.id).all.to_a).to match_array([])
      end
      it "should adjust all affected users" do
        allow(User).to receive(:find).with([ user_a.id ]).and_return([ user_a ])
        expect(user_a).to receive(:apply_access_profiles).with(remove_group_ids: [ group_a.id ]).and_return true
        post :destroy, params: {:id => ap_a.id}
      end
    end

  end

  #==========================================
  # Normal user: always 401
  #==========================================

  context "when the user is not an admin" do

    let(:current_user) { create(:normal_user) }

    before(:each) do
      session[:user_id] = current_user.id
      session[:session_id] = 'session_id'
    end

    describe "index" do
      it "should present the not authorized page" do
        get :index
        expect(response.code).to eq('401')
      end
    end
    describe "show" do
      it "should present the not authorized page" do
        get :show,  params: {:id => 1}
        expect(response.code).to eq('401')
      end
    end
    describe "new" do
      it "should present the not authorized page" do
        get :new
        expect(response.code).to eq('401')
      end
    end
    describe "create" do
      it "should present the not authorized page" do
        post :create
        expect(response.code).to eq('401')
      end
    end
    describe "update" do
      it "should present the not authorized page" do
        put :update, params: {:id => 1}
        expect(response.code).to eq('401')
      end
    end
    describe "destroy" do
      it "should present the not authorized page" do
        delete :destroy, params: {:id => 1}
        expect(response.code).to eq('401')
      end
    end
  end

  #==========================================
  # Not logged in: always back to login page
  #==========================================

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
    describe "new" do
      it "should redirect the login page" do
        get :new
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
  end

end

