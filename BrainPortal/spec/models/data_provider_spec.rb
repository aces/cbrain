#
# CBRAIN Project
#
# DataProvider spec
#
# Original author: Nicolas Kassis
#
# $Id$
#


require 'spec_helper'

describe DataProvider do
  before(:each) do 
    #objects required in tests below    
    @provider = Factory.create(:data_provider, :online => true, :read_only => false)
    @userfile = Factory.create(:userfile, :data_provider => @provider)
  end
  
  it "should create a new instance given valid attributes" do
    @provider.valid?.should be(true)
  end

  it "should not save with a blank name" do
    @provider.name = nil
    @provider.valid?.should be(false)
  end
  
  it "should not save with no owner" do
    @provider.user = nil
    @provider.valid?.should be(false)
  end
 
   it "should not save with no group" do 
     @provider.group =nil
     @provider.valid?.should be(false)
   end

   it "should not accept a dp without a value for read_only" do
     @provider.read_only = nil
     @provider.valid?.should be(false)
   end
   
   it "should accept read_only being false" do
     @provider.read_only = false
     @provider.valid?.should be true
   end
   
   it "should accept read_only being true" do 
     @provider.read_only = true
     @provider.valid?.should be true
   end
    
   it "should not accept a name with invalid chars" do 
     @provider.name = "*@$%"
     @provider.valid?.should be(false)
   end

   it "should not accept a remote_host with invalid chars" do 
     @provider.remote_host = "*@$%"
     @provider.valid?.should be(false)
   end


   it "should not accept a remote_user with invalid chars" do 
     @provider.remote_user = "*@$%"
     @provider.valid?.should be(false)
   end


   it "should not have a remote_dir path with invalid characters" do
     @provider.remote_dir = "*?$@"
     @provider.valid?.should be(false)
   end
   
   describe "#is_alive" do
      it "should return false when is_alive? is called on offline provider" do
        @provider.online = false
        @provider.is_alive?.should be(false)
     end
      
     it "should raise an exception if is_alive? called but not implemented in a subclass" do 
       lambda{@provider.is_alive?}.should raise_error("Error: method not yet implemented in subclass.")
     end
    
     it "should return false if impl_is_alive? returns false" do
       @provider.stub!(:impl_is_alive?).and_return(false)
       @provider.online = true
       @provider.is_alive?.should be(false)
     end
    
     it "should raise and exception when is_alive! is called with an offline provider" do
       @provider.online = false
       lambda{@provider.is_alive!}.should raise_error
     end
   end
    
    describe "#is_browsable" do
      it "should return false" do
        @provider.is_browsable?.should be(false)
      end
    end
     
    describe "#sync_to_cache" do
      it "should raise an exception if sync_to_cache is called but not implemented" do
        lambda{@provider.sync_to_cache(@userfile)}.should raise_error("Error: method not yet implemented in subclass.")
      end

      it "should return false if sync_to_cache is called and impl_sync_to_cache returns false" do
         @provider.stub!(:impl_sync_to_cache).and_return false

         @provider.sync_to_cache(@userfile).should be false
      end
    end
    
    describe "#sync_to_provider" do
      it "should raise an exception when sync_to_provider is called with an offline provider" do
        @provider.online = false
        lambda{@provider.sync_to_provider(@userfile)}.should raise_error(CbrainError, "Error: provider #{@provider.name} is offline.")
      end

      it "should raise an exception when sync_to_provider is called with read_only provider" do
        @provider.read_only = true
        lambda{@provider.sync_to_provider(@userfile)}.should raise_error(CbrainError, "Error: provider #{@provider.name} is read_only.")
      end

      it "should raise an exception when sync_to_provider called but not implemented" do
        lambda{@provider.sync_to_provider(@userfile)}.should raise_error("Error: method not yet implemented in subclass.")
      end

      it "should return false if I call sync_to_provider and impl_sync_to_provider is false" do
        @provider.instance_eval do 
          def impl_sync_to_provider(userfile)
            false
          end
        end
        @provider.sync_to_provider(@userfile).should be false
      end
    end
  
    describe "#cache_prepare" do
      it "should raise an exception when cache_prepare is called and provider is offline" do
        @provider.online = false 
        lambda{@provider.cache_prepare(@userfile)}.should raise_error(CbrainError, "Error: provider #{@provider.name} is offline.")
      end

      it "should raise an exception when cache_prepare is called on read only provider" do
         @provider.read_only = true
         lambda{@provider.cache_prepare(@userfile)}.should raise_error(CbrainError, "Error: provider #{@provider.name} is read_only.")
      end

      it "should return true when mkdir_cache_subdirs returns true (dp online and rw)" do
        @provider.instance_eval do
          def mkdir_cache_subdirs(userfile)
            true
          end
        end
        @provider.cache_prepare(@userfile).should be true
      end
    end
    
    describe "#cache_full_path" do
      it "should not raise an exception when cache_full_path is called on an offline provider" do
        @provider.online = false
        lambda{@provider.cache_full_path(@userfile)}.should_not raise_error
      end

      it "should return the value of cache_full_pathname(userfile) when cache_full_path is called on online provider" do
        @provider.instance_eval do
          def cache_full_pathname(usefile)
            true
          end
        end

        @provider.cache_full_path(@userfile).should be true
      end
    end
    
    describe "#cache_readhandle" do
      it "should raise an exception when provider is offline and cache_readhandle is called" do
        @provider.online = false
        lambda{@provider.cache_readhandle(@userfile)}.should raise_error(CbrainError, "Error: provider #{@provider.name} is offline.")
      end

      it "should raise an error when trying to use cache_readhandle and not implemented in a subclass" do 
        lambda{@provider.cache_readhandle(@userfile)}.should raise_error("Error: method not yet implemented in subclass.")
      end
    end
  
    describe "#cache_writehandle" do
      it "should raise an exception when I call cache_writehandle on offline provider" do
        @provider.online = false
        lambda{@provider.cache_writehandle(@userfile)}.should raise_error(CbrainError, "Error: provider #{@provider.name} is offline.")
      end

      it "should raise an exception when I call cache_writehandle on a read_only provider" do
        @provider.read_only = true
        lambda{@provider.cache_writehandle(@userfile)}.should raise_error(CbrainError, "Error: provider #{@provider.name} is read_only.")
      end

      it "should raise an exception if I call cache_writehandle with an fake file" do
        @provider.instance_eval do
          def mkdir_cache_subdirs(userfile)
            true
          end
        end
        lambda{@provider.cache_writehandle(@userfile)}.should raise_error Errno::ENOENT
      end
    end
    

end
