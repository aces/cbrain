
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

describe ActRecMetaData do
  let(:current_user) { create(:normal_user) }
  before(:each) do
    current_user.meta.attributes = {"key1" => "val1", "key2" => "val2"}
  end

  describe "#keys" do
    it "should return an array of all the keys defined in the metadata store" do
      expect(current_user.meta.keys).to match_array(["key1","key2"])
    end
  end

  describe "#attributes" do
    it "should return a hash containing all the metadata associated with the current ActiveRecord" do
      expect(current_user.meta.attributes).to eq({"key1"=> "val1", "key2"=> "val2"})
    end
  end

  describe "#attributes=" do
    it "should add a key and value to the metadata store" do
      add_hash = {"key3" => "val3"}
      current_user.meta.attributes = add_hash
      expect(current_user.meta.attributes).to eq({"key1"=> "val1", "key2"=> "val2", "key3" => "val3"})
    end
    it "should change a value in metadata store" do
      add_hash = {"key1" => "new_val1"}
      current_user.meta.attributes = add_hash
      expect(current_user.meta.attributes).to eq({"key1"=> "new_val1", "key2"=> "val2"})
    end
    it "should set several keys at once in metadata store" do
      add_hash = {"key3" => "val3", "key1" => "new_val1"}
      current_user.meta.attributes = add_hash
      expect(current_user.meta.attributes).to eq({"key1"=> "new_val1", "key2"=> "val2", "key3" => "val3"})
    end
  end

  describe "#[]=" do
    it "should set the value of the metadata key to my val if value not nil" do
      current_user.meta["key2"]="new_val2"
      expect(current_user.meta.attributes).to eq({"key1"=> "val1", "key2"=> "new_val2"})
    end
    it "should delete the key of the metadata if val is nil" do
      current_user.meta["key2"]=nil
      expect(current_user.meta.attributes).to eq({"key1"=> "val1"})
    end
    it "should add new key and value" do
      current_user.meta["key3"]="val3"
      expect(current_user.meta.attributes).to eq({"key1"=> "val1", "key2"=> "val2", "key3" => "val3"})
    end
  end

  describe "#[]" do
    it "should return value for key" do
      expect(current_user.meta["key1"]).to eq("val1")
    end
    it "should return nil value if key does not exist" do
      expect(current_user.meta["key3"]).to be_nil
    end
  end

  describe "#delete" do
    it "should delete entry for key" do
      current_user.meta.delete("key1")
      expect(current_user.meta.attributes).to eq({"key2" => "val2"})
    end
    it "should return nil for key does not exist" do
      expect(current_user.meta.delete("key3")).to be_nil
      expect(current_user.meta.attributes).to eq({"key1" => "val1" , "key2" => "val2"})
    end
  end

  describe "#all" do
    it "should return all the MetaDataStore objects associated with the current ActiveRecord object" do
      expect(current_user.meta.all.size).to eq(2)
      expect(current_user.meta.all.all? { |md| md.is_a?(MetaDataStore) && md.ar_id == current_user.id}).to be_truthy
    end
  end

  describe "#reload" do
    it "should not update cache if not called" do
      copied_user = User.find(current_user.id)
      copied_user.meta
      current_user.meta["key2"]="new_val2"
      expect(copied_user.meta.attributes).to eq({"key1"=> "val1", "key2"=> "val2"})
    end
    it "should update cache if called" do
      copied_user = User.find(current_user.id)
      copied_user.meta
      current_user.meta["key2"]="new_val2"
      expect(copied_user.meta.reload).to be_truthy
      expect(copied_user.meta.attributes).to eq({"key1"=> "val1", "key2"=> "new_val2"})
    end
  end

  describe "#destroy_all_meta_data" do
    it "should destry all meta data" do
      current_user.destroy_all_meta_data
      expect(current_user.meta.attributes).to be_empty
    end
  end

  describe "#find_all_by_meta_data" do # possible de le tester en faisant appel a la methode
    let(:other_user) { create(:normal_user) }
      before(:each) do
        other_user.meta.attributes = {"key1" => "new_val1"}
    end
    it "should find all models by metadata key" do
      expect(User.find_all_by_meta_data("key1")).to match_array([current_user , other_user])
    end
    it "should find all models by metadata key and value" do
      expect(User.find_all_by_meta_data("key1","val1")).to match_array([current_user])
    end
  end

end

