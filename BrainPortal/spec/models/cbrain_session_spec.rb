
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

describe CbrainSession do

  let(:session)      { { :session_id => 'dummy' } }
  let(:cb_session)   { CbrainSession.new(session) }
  let(:sess_model)   { cb_session.instance_eval { @model } } # ugly digging into implementation
  let(:current_user) { mock_model(User).as_null_object }


  describe "#activate" do

    before(:each) do
      session[:user_id] = 12345
    end

    it "should set the 'active' and 'user_id' attributes" do
      expect(sess_model).to receive(:user_id=).with(session[:user_id])
      expect(sess_model).to receive(:active=).with(true)
      expect(sess_model).to receive(:save!)
      cb_session.activate(session[:user_id])
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
      cb_class = CbrainSession.session_model
      expect(cb_class).to receive(:quoted_table_name)
      expect(User).to     receive(:quoted_table_name)
      expect(User).to     receive_message_chain(:joins, :where, :where)
      CbrainSession.active_users
    end

  end



  describe "self.recent_activity" do

    CbrainSession.session_model.delete_all

    1.upto(15) do |i|
      sess = CbrainSession.new( { :session_id => "xyz_#{i}" } )
      sess.activate(1)
    end

    it "should return an array containning recent activity (max n)" do
      allow(User).to receive(:find_by_id).and_return(current_user)
      n = 9
      expect(CbrainSession.recent_activity(n).size).to eq(n)
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
end
