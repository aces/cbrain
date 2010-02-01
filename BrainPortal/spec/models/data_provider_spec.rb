require 'spec_helper'

describe DataProvider do
  before(:each) do 
    #objects required in tests below
    @provider = Factory.create(:data_provider)
    @admin = Factory.create(:user, :role => "admin")
    @user = Factory.create(:user)
    @site_manager = Factory.create(:user, :site => @provider.user.site, :role => "site_manager")
    @site_manager.site.save 
    @random_dude = Factory.create(:user)
    @userfile = Factory.create(:userfile, :data_provider => @provider, :user => @user )
    
    #default state for provider
    @provider.online = true
    @provider.read_only = false
    
    
    #stub of impl_* methods 
    @provider.instance_eval do
        def impl_is_alive?
          true
        end
        def impl_sync_to_cache(userfile)
          true
        end
        def impl_sync_to_provider(userfile)
          true
        end
     end
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
    ############
    # is_alive #
    ############
   
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

        
    it ".is_alive? should set the time_of_death field to current time if the provider is down and time_of_death is nil" do
      @provider.instance_eval do
        def impl_is_alive?
          false
        end
      end
      
      @provider.time_of_death = nil 
      @provider.is_alive?
      (@provider.time_of_death - Time.now).should be_< 1.minute
    end

    it ".is_alive? should set the provider to offline if the time_of_death field is 1 minute old and impl_is_alive? returns false" do
      @provider.instance_eval do 
        def impl_is_alive?
          false
        end
      end
      @provider.time_of_death = 1.minute.ago
      @provider.is_alive? 
      @provider.online.should be false
    end
    it ".is_alive? should reset the time_of_death to now if the time_of_death field is < 2 minute old and impl_is_alive? returns false" do
      @provider.instance_eval do 
        def impl_is_alive?
          false
        end
      end
      @provider.time_of_death = 5.minute.ago
      @provider.is_alive? 
      (@provider.time_of_death-Time.now).should be_< 1.minute and @provider.online.should be true
      
    end
    
    it ".is_alive? should reset the time_of_death field if data_provider comes back online" do
      @provider.time_of_death = Time.now
      @provider.is_alive?
      @provider.time_of_death.should be nil
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
    
    
    #################
    # sync_to_cache #
    #################
    
    it "should raise an exception if sync_to_cache is called on an offline provider" do
      @provider.online = false
      lambda{@provider.sync_to_cache(@userfile)}.should raise_error "Error: provider is offline."
    end
    
    it "should return true when sync_to_cache is called and the provider is online and impl_sync_to_cache returns true" do
      @provider.online = true
      @provider.sync_to_cache(@userfile).should be true
    end
    
    it "should return false if sync_to_cache is called and impl_sync_to_cache returns false" do
       @provider.instance_eval do
         def impl_sync_to_cache(userfile)
           false
         end
       end
       
       @provider.sync_to_cache(@userfile).should be false
     
    end
    
    ############ Does sync_to_cache have other possibilities that needs testing?
    
    ####################
    # sync_to_provider #
    ####################
    
    
    it "should raise an exception when sync_to_provider is called with an offline provider" do
      @provider.online = false
      lambda{@provider.sync_to_provider(@userfile)}.should raise_error("Error: provider is offline.")
    end
    
    it "should raise an exception when sync_to_provider is called with read_only provider" do
      @provider.read_only = true
      lambda{@provider.sync_to_provider(@userfile)}.should raise_error "Error: provider is read_only."    
    end
    
    it "should return true when sync_to_provider is called on an online and rw provider and impl_sync_to_provider returns true" do
      @provider.sync_to_provider(@userfile).should be true
    end
    
    it "should return false if I call sync_to_provider and impl_sync_to_provider is false" do
      @provider.instance_eval do 
        def impl_sync_to_provider(userfile)
          false
        end
      end
      @provider.sync_to_provider(@userfile).should be false
    end
    #### like sync_to_cache, I can't think of anymore tests, please complete for sync_to_provider
    
    #################
    # cache_prepare #
    #################
    
    it "should raise an exception when cache_prepare is called and provider is offline" do
      @provider.online = false 
      lambda{@provider.cache_prepare(@userfile)}.should raise_error "Error: provider is offline."
    end
    
    it "should raise an exception when cache_prepare is called on read only provider" do
       @provider.read_only = true
       lambda{@provider.cache_prepare(@userfile)}.should raise_error "Error: provider is read_only."
    end
    
    it "should return true when mkdir_cache_subdirs returns true (dp online and rw)" do
      @provider.instance_eval do
        def mkdir_cache_subdirs(userfile)
          true
        end
      end
      @provider.cache_prepare(@userfile).should be true
    end
    
    ####################
    # cache_full_path #  
    ###################
    
    it "should raise an exception when cache_full_path is called on an offline provider" do
      @provider.online = false
      lambda{@provider.cache_full_path(@userfile)}.should raise_error "Error: provider is offline."
    end
    
    it "should return the value of cache_full_pathname(userfile) when cache_full_path is called on online provider" do
      @provider.instance_eval do
        def cache_full_pathname(usefile)
          true
        end
      end
      
      @provider.cache_full_path(@userfile).should be true
    end
    
    #################### 
    # cache_readhandle #
    ####################
    
    it "should raise an exception when provider is offline and cache_readhandle is called" do
      @provider.online = false
      lambda{@provider.cache_readhandle(@userfile)}.should raise_error "Error: provider is offline."
    end
    
    it "should raise an error when trying to use cache_readhandle on non-existant file" do 
      def cache_full_pathname(usefile)
        true
      end
      lambda{@provider.cache_readhandle(@userfile)}.should raise_error Errno::ENOENT
    end
    
    #####################
    # cache_writehandle #
    #####################
    
    it "should raise an exception when I call cache_writehandle on offline provider" do
      @provider.online = false
      lambda{@provider.cache_writehandle(@userfile)}.should raise_error "Error: provider is offline."
    end
    
    it "should raise an exception when I call cache_writehandle on a read_only provider" do
      @provider.read_only = true
      lambda{@provider.cache_writehandle(@userfile)}.should raise_error "Error: provider is read_only."
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
