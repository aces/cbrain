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
  let(:filter)  {Factory.create(:userfile_custom_filter)}

  describe "#filter_scope" do
    before(:each) do
      @userfile1 = Factory.create(:userfile, :name => "file_1", :created_at => "2011-04-04", :updated_at => "2011-05-04", :size => 1779)
      @userfile2 = Factory.create(:userfile, :name => "file_2", :created_at => "2011-04-29", :updated_at => "2011-05-29", :size => 2558)
    end

    it "should remove all task without 'data['user_id']'" do
      filter.data = { "user_id" => @userfile1.user_id }
      filter.filter_scope(Userfile.scoped({})).should =~ [@userfile1]
    end

    it "should remove all task without 'data['group_id']'" do
      filter.data = { "group_id" => @userfile1.group_id }
      filter.filter_scope(Userfile.scoped({})).should =~ [@userfile1]
    end

    it "should remove all task without 'data['data_provider_id']'" do
      filter.data = { "data_provider_id" => @userfile1.data_provider_id }
      filter.filter_scope(Userfile.scoped({})).should =~ [@userfile1]
    end
    
    it "should remove all non 'data['type']' userfile" do
      u1 = Factory.create(:niak_fmri_study)
      u2 = Factory.create(:userfile)
      filter.data = { "type" => u1.class.to_s }
      filter.filter_scope(Userfile.scoped({})).should =~ [u1]
    end

    context "with date" do
      
      it "should only keep userfile created between 'data['abs_from'] and 'data['abs_to']'" do
        filter.data = { "date_attribute" => "created_at", "absolute_or_relative_from"=>"abs", "absolute_or_relative_to"=>"abs", "abs_from" => "04/04/2011", "abs_to" => "04/04/2011" }
        filter.filter_scope(Userfile.scoped({})).should =~ [@userfile1]
      end
      
      it "should only keep task updates between 'data['abs_from'] and 'data['abs_to']'" do
        filter.data = { "date_attribute" => "updated_at", "absolute_or_relative_from"=>"abs", "absolute_or_relative_to"=>"abs", "abs_from" => "04/05/2011", "abs_to" => "04/05/2011" }
        filter.filter_scope(Userfile.scoped({})).should =~ [@userfile1]
      end

      it "should only keep task created between 'data['abs_from'] and 'data['rel_date_to']'" do
        filter.data = { "date_attribute" => "created_at", "absolute_or_relative_from"=>"abs", "absolute_or_relative_to"=>"rel", "abs_from" => "29/04/2011", "rel_date_to" => "0" }
        filter.filter_scope(Userfile.scoped({})).should =~ [@userfile2]
      end

      it "should only keep task updated between 'data['abs_from'] and 'data['rel_date_to']'" do
        filter.data = { "date_attribute" => "updated_at", "absolute_or_relative_from"=>"abs", "absolute_or_relative_to"=>"rel", "abs_from" => "29/05/2011", "rel_date_to" => "0" }
        filter.filter_scope(Userfile.scoped({})).should =~ [@userfile2]
      end

      it "should only keep task updated last week" do
        filter.data = { "date_attribute" => "updated_at", "absolute_or_relative_from"=>"rel", "absolute_or_relative_to"=>"rel", "rel_date_from" => "#{1.week}", "rel_date_to" => "0" }
        @userfile1.updated_at = Date.today - 1.day
        @userfile1.save!
        filter.filter_scope(Userfile.scoped({})).should =~ [@userfile1]
      end
      
    end

    context "with size" do
      it "should remove all userfile with size lower than 'data['size_term']'" do
        filter.data = { "size_type" => "1", "size_term" => (@userfile2.size.to_f/1000) }
        filter.filter_scope(Userfile.scoped({})).should =~ [@userfile1]
      end
      
      it "should remove all userfile with size equal 'data['size_term']'" do
        filter.data = { "size_type" => "0", "size_term" => (@userfile2.size.to_f/1000) }
        filter.filter_scope(Userfile.scoped({})).should =~ [@userfile2]
      end
      
      it "should remove all userfile with size greater than 'data['size_term']'" do
        filter.data = { "size_type" => "2", "size_term" => (@userfile1.size.to_f/1000) }
        filter.filter_scope(Userfile.scoped({})).should =~ [@userfile2]
      end
    end

    context "with name scope" do
      it "should remove all userfile doesn't match with 'data['file_name_term']'" do
        filter.data = { "file_name_type" => "match", "file_name_term" => @userfile1.name }
        filter.filter_scope(Userfile.scoped({})).should =~ [@userfile1]
      end
    
      it "should remove all userfile doesn't begin with 'data['file_name_term']'" do
        filter.data = { "file_name_type" => "begin", "file_name_term" => @userfile1.name[0..2] }
        filter.filter_scope(Userfile.scoped({})).should =~ [@userfile1,@userfile2]
      end
      
      it "should remove all userfile doesn't end with 'data['file_name_term']'" do
        filter.data = { "file_name_type" => "end", "file_name_term" => @userfile1.name[-1].chr }
        filter.filter_scope(Userfile.scoped({})).should =~ [@userfile1]
      end

      it "should remove all userfile doesn't contain 'data['file_name_term']'" do
        filter.data = { "file_name_type" => "contain", "file_name_term" => @userfile1.name[1..3] }
        filter.filter_scope(Userfile.scoped({})).should =~ [@userfile1,@userfile2]
      end
    end
  end

  context "tag management" do
    let(:tag1) {Factory.create(:tag)}
    let(:tag2) {Factory.create(:tag)}
    
    describe "#tag_ids=" do
      it "should assign tags to the data hash" do
        filter.tag_ids=( [tag1.id.to_i] )
        filter.tags.should =~ [tag1.name.to_s]
      end
    end
  
    describe "#tags" do
      
      it "should return empty array if no tags is used" do
        filter.data = nil
        filter.tags.should be_empty
      end
      it "should return only the tags in the data hash" do
        filter.data = { "tags" => [tag1.name.to_s,tag2.name.to_s]}
        filter.tags.should =~ [tag1.name.to_s,tag2.name.to_s]
      end
    end
  end
  
  describe "#date_term=" do
    it "should assign the date_term in the data hash" do
      date = {"date_term(1i)"=>"2011", "date_term(2i)"=>"05", "date_term(3i)"=>"24"}
      filter.date_term=(date)
      filter.date_term.should == "#{date["date_term(1i)"]}-#{date["date_term(2i)"]}-#{date["date_term(3i)"]}"
    end
  end

  
  describe "#date_term" do
    it "should return nil if date_term is not defined" do
      filter.date_term.should be nil
    end
  end
  
end
