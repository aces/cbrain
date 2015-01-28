
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

describe CbrainSession do

  let(:session)    {Hash.new}
  let(:sess_model) {double("sess_model").as_null_object}
  let(:cb_session) {CbrainSession.new(session, {:controller => "userfiles"}, sess_model)}
  let(:current_user) { mock_model(User).as_null_object }


  describe "#initialize" do

    it "should add a hash for contoller with filter_hash and sort_hash if doesn't exist" do
      expect(cb_session[:userfiles]["filter_hash"]).to eq({})
      expect(cb_session[:userfiles]["sort_hash"]).to eq({})
    end

  end

  describe "#load_preferences_for_user" do
    let(:meta_data) { double("meta").as_null_object}

    it "should get meta data from the db" do
      expect(current_user).to receive(:meta).and_return({})
      cb_session.load_preferences_for_user(current_user)
    end

    it "should get preferences from the meta data" do
      allow(current_user).to receive(:meta).and_return(meta_data)
      expect(meta_data).to receive(:[]).with(:preferences)
      cb_session.load_preferences_for_user(current_user)
    end

  end

  describe "#save_preferences_for_user" do
    let(:user_preferences) { Hash.new }

    before(:each) do
      session[:controller] = {"key" => "value"}
      allow(current_user).to receive_message_chain(:meta, :[], :cb_deep_clone).and_return(user_preferences)
      allow(current_user).to receive_message_chain(:meta, :[]=)
    end

    it "should add session preference to db if they are listed" do
      cb_session.save_preferences_for_user(current_user, :controller, :key)
      expect(user_preferences[:controller].keys).to include("key")
    end

    it "should add session preference to db if they are listed" do
      cb_session.save_preferences_for_user(current_user, :controller)
      expect(user_preferences[:controller].keys).not_to include("key")
    end

  end

  describe "#activate" do

    before(:each) do
      session[:user_id] = 12345
    end

    it "should set the 'active' and 'user_id' attributes" do
      expect(sess_model).to receive(:user_id=).with(session[:user_id])
      expect(sess_model).to receive(:active=).with(true)
      expect(sess_model).to receive(:save!)
      cb_session.activate
    end

  end



  describe "#deactivate" do

    it "should reset the 'active' attribute" do
      expect(sess_model).to receive(:active=).with(false)
      expect(sess_model).to receive(:save!)
      cb_session.deactivate
    end

  end



  describe "self.activate_users" do

    it "should call where on session_class and where on User.where" do
      cb_class = ActiveRecord::SessionStore::Session
      cb_scope = double("cb_scope").as_null_object
      expect(cb_class).to receive(:where).and_return(cb_scope)
      us_scope = double("us_scope")
      expect(User).to receive(:where).and_return(us_scope)
      expect(us_scope).to receive(:where)
      CbrainSession.active_users
    end

  end



  describe "self.count" do

    it "should call where on session_class and count on scope" do
      cb_class = ActiveRecord::SessionStore::Session
      scope = double("scope").as_null_object
      expect(cb_class).to receive(:where).and_return(scope)
      expect(scope).to receive(:count)
      CbrainSession.count
    end

  end



  describe "self.session_class" do

    it "should return ActiveRecord::SessionStore::Session" do
      cb_class = ActiveRecord::SessionStore::Session
      expect(CbrainSession.session_class).to eq(cb_class)
     end

  end



  describe "self.all" do

    it "should call all on session_class" do
      cb_class = ActiveRecord::SessionStore::Session
      expect(CbrainSession).to receive(:session_class).and_return(cb_class)
      expect(cb_class).to receive(:all)
      CbrainSession.all
    end

  end



  describe "self.recent_activity" do
    1.upto(15) do |i|
      name = "cb_session#{i}"
      sess = ActiveRecord::SessionStore::Session.create!( :updated_at => (i*10).seconds.ago, :session_id => "xyz#{i}", :data => {})
      sess.user_id = i
      sess.active  = true
      sess.save
      user = "user#{i}"
      let!(:name) { CbrainSession.new(sess, {:controller => "userfile"}, sess_model) }
    end

    it "should return an array containning recent activity (max n)" do
      allow(CbrainSession).to receive(:clean_sessions).and_return(true)
      allow(User).to receive(:find_by_id).and_return(current_user)
      n = 9
      expect(CbrainSession.recent_activity(n).size).to eq(n)
    end

  end



  describe "#clear_data!" do

    it "should erase all entries in the data section exception of guessed_remote_host and raw_user_agent" do
      cb_session[:guessed_remote_host] = "guessed_remote_host"
      cb_session[:raw_user_agent]      = "raw_user_agent"
      cb_session[:other]               = "other"
      cb_session.clear_data!
      expect(cb_session[:guessed_remote_host]).to eq("guessed_remote_host")
      expect(cb_session[:raw_user_agent]).to      eq("raw_user_agent")
      expect(cb_session[:other]).to               be_nil
    end

  end



  describe "update" do

    it "should add a new hash if attributes of the session doesn't have hash with same name" do
      hash1 = {"key1" => "val1"}
      params = {:controller => :userfiles, :userfiles => {"new_hash" => hash1}}
      cb_session.update(params)
      expect(cb_session[:userfiles]["new_hash"]).to eq(hash1)
    end

    it "should merge hash if attributes of the session have hash with same name" do
      hash1 = {"key1" => "val1"}
      hash2 = {"key2" => "val2"}
      merge_hash = hash1.merge!(hash2)
      cb_session[:userfiles]["new_hash"] = hash1
      params = {:controller => :userfiles, :userfiles => {"new_hash" => hash2}}
      cb_session.update(params)
      expect(cb_session[:userfiles]["new_hash"]).to eq(merge_hash)
    end

    it "should add a new array if attributes of the session doesn't have hash with same name" do
      params = {:controller => :userfiles, :userfiles => {"new_array" => 1}}
      cb_session.update(params)
      expect(cb_session[:userfiles]["new_array"]).to eq([1])
    end

    it "should merge array if attributes of the session have array with same name" do
      array1 = [1,2,3]
      cb_session[:userfiles]["new_array"] = array1
      final_array = array1 + [4]
      params = {:controller => :userfiles, :userfiles => {"new_array" => 4}}
      cb_session.update(params)
      expect(cb_session[:userfiles]["new_array"]).to match_array(final_array)
    end

    it "should remove specific item in list" do
      full_hash = {"key1" => "val1", "key2" => "val2"}
      cb_session[:userfiles]["hash"] = full_hash
      to_rm = "key1"
      params = {:controller => :userfiles, :userfiles => {"remove" => {"hash" => to_rm}}}
      part_hash = full_hash
      part_hash.delete to_rm
      cb_session.update(params)
      expect(cb_session[:userfiles]["hash"]).to eq(part_hash)
    end

    it "should remove all list if @session[controller.to_sym][list] not respond to delete " do
      cb_session[:userfiles]["hash"] = 2
      params = {:controller => :userfiles, :userfiles => {"remove" => {"hash" => true}}}
      cb_session.update(params)
      expect(cb_session[:userfiles]["hash"]).to be_nil
    end

    it "should return to initial state for @session[controller]" do
      cb_session[:userfiles]["hash"] = {"key1" => "val1", "key2" => "val2"}
      params = {:controller => :userfiles, :userfiles => {"clear_all" => "all"}}
      cb_session.update(params)
      expect(cb_session[:userfiles]["hash"]).to        be_nil
      expect(cb_session[:userfiles]["filter_hash"]).to eq({})
      expect(cb_session[:userfiles]["sort_hash"]).to   eq({})
    end

    it "should clear specific hash" do
      cb_session[:userfiles]["hash"] = {"key1" => "val1", "key2" => "val2"}
      params = {:controller => :userfiles, :userfiles => {"clear_hash" => 1}}
      cb_session.update(params)
      expect(cb_session[:userfiles]["hash"]).to eq({})
    end

    it "should clear specific value" do
      cb_session[:userfiles]["val"] = 1
      params = {:controller => :userfiles, :userfiles => {"clear_val" => 1}}
      cb_session.update(params)
      expect(cb_session[:userfiles]["val"]).to be_nil
    end

  end



  describe "params_for" do

    it "should return the params saved for +controller+" do
      hash = {"filter_hash"=>{}}
      cb_session[:userfiles] = hash
      expect(cb_session.params_for("userfiles")).to eq(hash)
    end

  end



  describe "[]" do

    it "should acces to session attributes" do
      hash = {"filter_hash"=>{}}
      cb_session[:userfiles] = hash
      expect(cb_session[:userfiles]).to eq(hash)
    end

  end



  describe "[]=" do

    it "should assign value to session attribute" do
      hash = {"filter_hash"=>{}}
      cb_session[:userfiles] = hash
      expect(cb_session[:userfiles]).to eq(hash)
    end

  end



  describe "method_missing" do

    it "should return the params saved for +controller+" do
      hash = {"filter_hash"=>{}}
      cb_session[:userfiles] = hash
      expect(cb_session.method_missing("userfiles")).to eq(hash)
    end

  end



  describe "persistent_userfile_ids_clear" do

    it "should clear persistent_userfile_ids hash" do
      cb_session[:persistent_userfile_ids] = [0,1,2]
      cb_session.persistent_userfile_ids_clear
      expect(cb_session[:persistent_userfile_ids]).to eq({})
    end

    it "should return size of original persistent_userfile_ids" do
      cb_session[:persistent_userfile_ids] = [0,1,2]
      expect(cb_session.persistent_userfile_ids_clear).to eq(3)
    end

  end



  describe "persistent_userfile_ids_add" do

    it "should add id in id_list only if not already present" do
      cb_session[:persistent_userfile_ids] = {1 => true}
      cb_session.persistent_userfile_ids_add([3,2])
      expect(cb_session[:persistent_userfile_ids]).to match({1 => true, 2 => true, 3 => true})
    end

    it "should return number of added elem" do
      cb_session[:persistent_userfile_ids] = {1 => true}
      expect(cb_session.persistent_userfile_ids_add([1,2])).to eq(1)
    end

  end



  describe "persistent_userfile_ids_remove" do

    it "should remove id in id_list only if already present" do
      cb_session[:persistent_userfile_ids] = {1 => true, 2 => true, 3 => true}
      cb_session.persistent_userfile_ids_remove([3,2])
      expect(cb_session[:persistent_userfile_ids]).to match({1 => true})
    end

    it "should return number of removed elem" do
      cb_session[:persistent_userfile_ids] = {1 => true}
      expect(cb_session.persistent_userfile_ids_remove([2])).to eq(0)
    end

  end



  describe "persistent_userfile_ids_list" do

    it "should return array with persistent_userfile_ids_list" do
      hash = {1 => true, 2 => true, 3 => true}
      cb_session[:persistent_userfile_ids] = hash
      expect(cb_session.persistent_userfile_ids_list).to eq(hash.keys)
    end

  end



  describe "persistent_userfile_ids" do

   it "should return hash with persistent_userfile_ids_list" do
      hash = {1 => true, 2 => true, 3 => true}
      cb_session[:persistent_userfile_ids] = hash
      expect(cb_session.persistent_userfile_ids).to eq(hash)
    end

  end

end

