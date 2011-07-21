
#
# CBRAIN Project
#
# SingleFile spec
#
# Original author: Natacha Beck
#
# $Id$
#


require 'spec_helper'

describe SingleFile do
  let(:single_file) { Factory.create(:single_file)}
  let(:file_entry)  { double("file_entry", :size => 1024).as_null_object}
        
  before(:each) do
    single_file.stub!(:list_files).and_return([file_entry])
  end
  
  describe "#set_size!" do
    
    it "should set size to addition of file_entry.size" do
      single_file.set_size
      single_file.reload
      single_file.size.should == 1024
    end
  end
  
end               
