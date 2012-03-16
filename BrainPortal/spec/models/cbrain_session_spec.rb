
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
  
  let!(:session)    {Hash.new}
  let!(:sess_model) {double("sess_model").as_null_object}
  let!(:cb_session) {CbrainSession.new(session, {:controller => "userfiles"}, sess_model)}


  
  describe "initialize" do

    it "should add a hash for contoller with filter_hash and sort_hash if doesn't exist" do
      cb_session[:userfiles]["filter_hash"].should be == {}
      cb_session[:userfiles]["sort_hash"].should be == {}
    end
    
  end


  
  describe "activate" do

    it "should call update_attributes!" do
      sess_model.should_receive(:update_attributes!).with(:user_id => cb_session.user_id, :active => true)
      cb_session.activate
    end
    
  end


  
  describe "deactivate" do
    
    it "should call update_attributes!" do
      sess_model.should_receive(:update_attributes!).with(:active => false)
      cb_session.deactivate
    end
    
  end


  
  describe "self.activate_users" do
    
    it "should call where on session_class and where on User.where" do
      cb_class = ActiveRecord::SessionStore::Session
      cb_scope = double("cb_scope").as_null_object
      cb_class.should_receive(:where).and_return(cb_scope)
      us_scope = double("us_scope")
      User.should_receive(:where).and_return(us_scope)
      us_scope.should_receive(:where)
      CbrainSession.active_users
    end
    
  end


  
  describe "self.count" do
   
    it "should call where on session_class and count on scope" do
      cb_class = ActiveRecord::SessionStore::Session
      scope = double("scope").as_null_object
      cb_class.should_receive(:where).and_return(scope)
      scope.should_receive(:count)
      CbrainSession.count
    end
  
  end


  
  describe "self.session_class" do
    
    it "should return ActiveRecord::SessionStore::Session" do
      cb_class = ActiveRecord::SessionStore::Session
      CbrainSession.session_class.should be == cb_class
     end
      
  end


  
  describe "self.all" do
    
    it "should call all on session_class" do
      cb_class = ActiveRecord::SessionStore::Session
      CbrainSession.should_receive(:session_class).and_return(cb_class)
      cb_class.should_receive(:all)
      CbrainSession.all
    end

  end


  
  describe "self.recent_activity" do
      1.upto(15) do |i|
        name = "cb_session#{i}"
        sess = ActiveRecord::SessionStore::Session.create!( :updated_at => (i*10).seconds.ago, :session_id => "xyz#{i}", :data => {}, :user_id => i, :active => true )
        user = "user#{i}"
        let!(user.to_sym) {Factory.create(:normal_user, :id => i)} if User.where(:id => i).size == 0
        let!(name.to_sym) {CbrainSession.new(sess, {:controller => "userfile"}, sess_model)}
      end
      
    it "should return an array containning recent activity (max n)" do
      n = 9 
      CbrainSession.recent_activity(n).size.should be == n  
    end
    
  end


  
  describe "clear_data!" do
   
    it "should erase all entries in the data section exception of guessed_remote_host and raw_user_agent" do
      cb_session[:guessed_remote_host] = "guessed_remote_host"
      cb_session[:raw_user_agent]      = "raw_user_agent"
      cb_session[:other]               = "other"
      cb_session.clear_data!
      cb_session[:guessed_remote_host].should be == "guessed_remote_host"
      cb_session[:raw_user_agent].should      be == "raw_user_agent"
      cb_session[:other].should               be_nil
    end
    
  end


  
  describe "update" do

    it "should add a new hash if attributes of the session doesn't have hash with same name" do
      hash1 = {"key1" => "val1"}
      params = {:controller => :userfiles, :userfiles => {"new_hash" => hash1}}
      cb_session.update(params)
      cb_session[:userfiles]["new_hash"].should be == hash1
    end

    it "should merge hash if attributes of the session have hash with same name" do
      hash1 = {"key1" => "val1"}
      hash2 = {"key2" => "val2"}
      merge_hash = hash1.merge!(hash2)
      cb_session[:userfiles]["new_hash"] = hash1
      params = {:controller => :userfiles, :userfiles => {"new_hash" => hash2}}
      cb_session.update(params)
      cb_session[:userfiles]["new_hash"].should be == merge_hash
    end

    it "should add a new array if attributes of the session doesn't have hash with same name" do
      params = {:controller => :userfiles, :userfiles => {"new_array" => 1}}
      cb_session.update(params)
      cb_session[:userfiles]["new_array"].should be == [1]
    end

    it "should merge array if attributes of the session have array with same name" do
      array1 = [1,2,3]
      cb_session[:userfiles]["new_array"] = array1
      final_array = array1 + [4]
      params = {:controller => :userfiles, :userfiles => {"new_array" => 4}}
      cb_session.update(params)
      cb_session[:userfiles]["new_array"].should =~ final_array
    end

    it "should remove specific item in list" do
      full_hash = {"key1" => "val1", "key2" => "val2"}
      cb_session[:userfiles]["hash"] = full_hash
      to_rm = "key1"
      params = {:controller => :userfiles, :userfiles => {"remove" => {"hash" => to_rm}}}
      part_hash = full_hash
      part_hash.delete to_rm
      cb_session.update(params)
      cb_session[:userfiles]["hash"].should be == part_hash
    end

    it "should remove all list if @session[controller.to_sym][list] not respond to delete " do
      cb_session[:userfiles]["hash"] = 2
      params = {:controller => :userfiles, :userfiles => {"remove" => {"hash" => true}}}
      cb_session.update(params)
      cb_session[:userfiles]["hash"].should be_nil
    end

    it "should return to initial state for @session[controller]" do
      cb_session[:userfiles]["hash"] = {"key1" => "val1", "key2" => "val2"}
      params = {:controller => :userfiles, :userfiles => {"clear_all" => "all"}}
      cb_session.update(params)
      cb_session[:userfiles]["hash"].should        be_nil
      cb_session[:userfiles]["filter_hash"].should be == {}
      cb_session[:userfiles]["sort_hash"].should   be == {}
    end

    it "should clear specific hash" do
      cb_session[:userfiles]["hash"] = {"key1" => "val1", "key2" => "val2"}
      params = {:controller => :userfiles, :userfiles => {"clear_hash" => 1}}
      cb_session.update(params)
      cb_session[:userfiles]["hash"].should be == {}
    end

    it "should clear specific value" do
      cb_session[:userfiles]["val"] = 1
      params = {:controller => :userfiles, :userfiles => {"clear_val" => 1}}
      cb_session.update(params)
      cb_session[:userfiles]["val"].should be_nil
    end

  end


  
  describe "params_for" do

    it "should return the params saved for +controller+" do
      hash = {"filter_hash"=>{}}
      cb_session[:userfiles] = hash
      cb_session.params_for("userfiles").should be == hash
    end

  end


  
  describe "[]" do

    it "should acces to session attributes" do
      hash = {"filter_hash"=>{}}
      cb_session[:userfiles] = hash
      cb_session[:userfiles].should be == hash
    end
    
  end


  
  describe "[]=" do
    
    it "should assign value to session attribute" do
      hash = {"filter_hash"=>{}}
      cb_session[:userfiles] = hash 
      cb_session[:userfiles].should be == hash
    end
    
  end


  
  describe "method_missing" do

    it "should return the params saved for +controller+" do
      hash = {"filter_hash"=>{}}
      cb_session[:userfiles] = hash
      cb_session.method_missing("userfiles").should be == hash
    end
    
  end


  
  describe "persistent_userfile_ids_clear" do
    
    it "should clear persistent_userfile_ids hash" do
      cb_session[:persistent_userfile_ids] = [0,1,2]
      cb_session.persistent_userfile_ids_clear
      cb_session[:persistent_userfile_ids].should be == {}
    end

    it "should return size of original persistent_userfile_ids" do
      cb_session[:persistent_userfile_ids] = [0,1,2]
      cb_session.persistent_userfile_ids_clear.should be == 3
    end 
    
  end


  
  describe "persistent_userfile_ids_add" do

    it "should add id in id_list only if not already present" do
      cb_session[:persistent_userfile_ids] = {1 => true}
      cb_session.persistent_userfile_ids_add([3,2])
      cb_session[:persistent_userfile_ids].should be =~ {1 => true, 2 => true, 3 => true}
    end
  
    it "should return number of added elem" do
      cb_session[:persistent_userfile_ids] = {1 => true}
      cb_session.persistent_userfile_ids_add([1,2]).should be == 1
    end

  end


  
  describe "persistent_userfile_ids_remove" do
    
    it "should remove id in id_list only if already present" do
      cb_session[:persistent_userfile_ids] = {1 => true, 2 => true, 3 => true}
      cb_session.persistent_userfile_ids_remove([3,2])
      cb_session[:persistent_userfile_ids].should be =~ {1 => true}
    end

    it "should return number of removed elem" do
      cb_session[:persistent_userfile_ids] = {1 => true}
      cb_session.persistent_userfile_ids_remove([2]).should be == 0
    end
      
  end


  
  describe "persistent_userfile_ids_list" do
    
    it "should return array with persistent_userfile_ids_list" do 
      hash = {1 => true, 2 => true, 3 => true}
      cb_session[:persistent_userfile_ids] = hash
      cb_session.persistent_userfile_ids_list.should be == hash.keys
    end
    
  end


  
  describe "persistent_userfile_ids" do

   it "should return hash with persistent_userfile_ids_list" do 
      hash = {1 => true, 2 => true, 3 => true}
      cb_session[:persistent_userfile_ids] = hash
      cb_session.persistent_userfile_ids.should be == hash
    end
    
  end
  
end

