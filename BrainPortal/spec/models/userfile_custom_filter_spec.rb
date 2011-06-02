#
# CBRAIN Project
#
# UserfileCustomFilter spec
#
# Original author: Natacha Beck
#
# $Id$
#


require 'spec_helper'

describe UserfileCustomFilter do
  let(:tag1) { double("tag1", :id => 1, :name => "tag_1").as_null_object }
  let(:tag2) { double("tag2", :id => 2, :name => "tag_2").as_null_object }
  let(:ucf)  {Factory.create(:userfile_custom_filter, :data =>  { "tags" => [tag1.name.to_s,tag2.name.to_s]})}

  describe "#filter_scope" do
    before(:each) do
      @userfile1 = Factory.create(:userfile, :name => "file_1", :user_id => 1, :group_id => 1, :created_at => "2011-04-04", :size => 1779)
      @userfile2 = Factory.create(:userfile, :name => "file_2", :user_id => 2, :group_id => 2, :created_at => "2011-04-29", :size => 2558)
    end

    it "should remove all task without 'data['user_id']'" do
      ucf.data = { "user_id" => @userfile1.user_id }
      ucf.filter_scope(Userfile.scoped({})).should =~ [@userfile1]
    end

    it "should remove all task without 'data['group_id']'" do
      ucf.data = { "group_id" => @userfile1.group_id }
      ucf.filter_scope(Userfile.scoped({})).should =~ [@userfile1]
    end

    it "should remove all task without 'data['data_provider_id']'" do
      ucf.data = { "data_provider_id" => @userfile1.data_provider_id }
      ucf.filter_scope(Userfile.scoped({})).should =~ [@userfile1]
    end
    
    it "should remove all non 'data['type']' userfile" do
      u1 = Factory.create(:niak_fmri_study)
      u2 = Factory.create(:userfile)
      ucf.data = { "type" => u1.class.to_s }
      ucf.filter_scope(Userfile.scoped({})).should =~ [u1]
    end

    context "with date" do
      it "should remove all userfile created before 'data['date_term']'" do
        ucf.data = { "created_date_type" => 1, "date_term" => @userfile2.created_at }
        ucf.filter_scope(Userfile.scoped({})).should =~ [@userfile1]
      end
      
      it "should remove all userfile created on 'data['date_term']'" do
        ucf.data = { "created_date_type" => 0, "date_term" => @userfile2.created_at }
        ucf.filter_scope(Userfile.scoped({})).should =~ [@userfile2]
      end
      
      it "should remove all userfile created after 'data['date_term']'" do
        ucf.data = { "created_date_type" => 2, "date_term" => @userfile1.created_at }
        ucf.filter_scope(Userfile.scoped({})).should =~ [@userfile2]
      end
    end

    context "with size" do
      it "should remove all userfile with size lower than 'data['size_term']'" do
        ucf.data = { "size_type" => "1", "size_term" => (@userfile2.size.to_f/1000) }
        ucf.filter_scope(Userfile.scoped({})).should =~ [@userfile1]
      end
      
      it "should remove all userfile with size equal 'data['size_term']'" do
        ucf.data = { "size_type" => "0", "size_term" => (@userfile2.size.to_f/1000) }
        ucf.filter_scope(Userfile.scoped({})).should =~ [@userfile2]
      end
      
      it "should remove all userfile with size greater than 'data['size_term']'" do
        ucf.data = { "size_type" => "2", "size_term" => (@userfile1.size.to_f/1000) }
        ucf.filter_scope(Userfile.scoped({})).should =~ [@userfile2]
      end
    end

    context "with name scope" do
      it "should remove all userfile doesn't match with 'data['file_name_term']'" do
        ucf.data = { "file_name_type" => "match", "file_name_term" => @userfile1.name }
        ucf.filter_scope(Userfile.scoped({})).should =~ [@userfile1]
      end
    
      it "should remove all userfile doesn't begin with 'data['file_name_term']'" do
        ucf.data = { "file_name_type" => "begin", "file_name_term" => @userfile1.name[0..2] }
        ucf.filter_scope(Userfile.scoped({})).should =~ [@userfile1,@userfile2]
      end
      
      it "should remove all userfile doesn't end with 'data['file_name_term']'" do
        ucf.data = { "file_name_type" => "end", "file_name_term" => @userfile1.name[-1].chr }
        ucf.filter_scope(Userfile.scoped({})).should =~ [@userfile1]
      end

      it "should remove all userfile doesn't contain 'data['file_name_term']'" do
        ucf.data = { "file_name_type" => "contain", "file_name_term" => @userfile1.name[1..3] }
        ucf.filter_scope(Userfile.scoped({})).should =~ [@userfile1,@userfile2]
      end
    end
  end

  describe "#tag_ids=" do
    tag1 = Factory.create(:tag)
    tag2 = Factory.create(:tag)
    it "should assign tags to the data hash" do
      ucf.tag_ids=( [Tag.find(1).id.to_i] )
      ucf.tags.should =~ [Tag.find(1).name.to_s]
    end
  end

  describe "#tags" do
    it "should return empty array if no tags is used" do
      ucf.data = nil
      ucf.tags.should be_empty
    end
    it "should return only the tags in the data hash" do
      ucf.data = { "tags" => [tag1.name.to_s,tag2.name.to_s]}
      ucf.tags.should =~ [tag1.name.to_s,tag2.name.to_s]
    end
  end

  describe "#date_term=" do
    it "should assign the date_term in the data hash" do
      date = {"date_term(1i)"=>"2011", "date_term(2i)"=>"05", "date_term(3i)"=>"24"}
      ucf.date_term=(date)
      ucf.date_term.should == "#{date["date_term(1i)"]}-#{date["date_term(2i)"]}-#{date["date_term(3i)"]}"
    end
  end

  
  describe "#date_term" do
    it "should return nil if date_term is not defined" do
      ucf.date_term.should be nil
    end
  end
  
end
