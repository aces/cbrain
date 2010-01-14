require 'spec_helper'

describe DataProvider do
  before(:each) do 
    #objects required in tests below
    @provider = Factory.build(:data_provider)
    @admin = Factory.create(:user, :role => "admin")
    @user = Factory.create(:user)
    @site_manager = Factory.create(:user, :site => @provider.user.site, :role => "site_manager")
    @site_manager.site.save 
    @random_dude = Factory.create(:user)
   
   
    #mock of impl_* methods 
    @provider.instance_eval do
        def impl_is_alive?
          true
        end
        def impl_sync_to_cache(userfile)
          true
        end
     end
  end

  it "should create a new instance given valid attributes" do
    @provider.save.should be(true)
  end

  it "should not save with a blank name" do
    @provider.name = nil
    @provider.save.should be(false)
  end
  
  it "should not save with no owner" do
    @provider.user = nil
    @provider.save.should be(false)
  end
 
   it "should not save with no group" do 
     @provider.group =nil
     @provider.valid?.should be(false)
   end

   it "should not accept a dp without a value for read_only" do
     @provider.read_only = nil
     @provider.valid?.should be(false)
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

   it "should return false when is_alive? is called on offline provider" do
     @provider.online = false
     @provider.is_alive?.should be(false)
   end
   
   it "should return true when is_alive is a called on online provider" do 
     @provider.online = true
     @provider.is_alive?.should be(true)
   end
    
   it "should return false if impl_is_alive? returns false" do
     @provider.instance_eval do
       def impl_is_alive?
         false
       end
      end
      @provider.online = true
      @provider.is_alive?.should be(false)
    end
    
    it "should return true when is_alive! is called with is_alive? returning true" do
      @provider.online = true
      @provider.is_alive!.should be(true)
    end
    
    it "should raise and exception when is_alive! is called with an offline provider" do
      @provider.online = false
      begin
        @provider.is_alive!
      rescue
        true
      end
    end
    
    it "should return false when is_browsable? is called" do
      @provider.is_browsable?.should be(false)
    end
    
    it "should be accesible by admin" do
      @provider.can_be_accessed_by?(@admin).should be(true)
    end
    
    it "should be accessible by a site manager of the data_provider's site" do
      @provider.can_be_accessed_by?(@site_manager).should be(true)
    end
    
    it "should be accessible by a user in the data provider's site" do
      @user.groups << @provider.group
      @provider.can_be_accessed_by?(@user).should be(true)
    end
    
    it "should not be accessible by any other random user" do
      @provider.can_be_accessed_by?(@random_dude).should be(false)
    end
    
    it "should return true that admins have owner access of this provider" do
      @provider.has_owner_access?(@admin).should be(true)
    end

    it "should return true that the owner of the data_provider has owner access" do
      @provider.has_owner_access?(@provider.user)
    end
    
    it "should return true that the site manager of the provider has owner access" do
      @provider.has_owner_access?(@site_manager)
    end
    
    it "should return false that random user has owner access" do
      @provider.has_owner_access?(@random_dude)
    end

    #Needs more test
    
end