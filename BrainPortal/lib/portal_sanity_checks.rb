#
# CBRAIN Project
#
# Sanity library for brainportal (this file was split from validation_portal.rb initializer 
#
# Original author: Nicolas Kassis
# 
# $Id$
#
# This file contains a singleton Portal sanity checker class
# Each sanity(database consitency) check is created in a instance method of the class 
# The class will run all instance methods named ensure_* when self.become is 
# called after a new revision.
# The class creates new sanity check records when it is run after a new revision
# to this file. 
#
# self.check has been overloaded to add a database record when checks are run to prevent
# multiple runs of the test and to ensure that the test have been runned in the past
#
# The is a rake task to run these sanity checks called rake db:sanity:check
# This rake task should be run before starting cbrain for the first time. 
#


require 'socket'

class PortalSanityChecks < CbrainChecker

  Revision_info="$Id$"

  #Checks to see if the validation was run since last change
  def self.done?
    if SanityCheck.find_by_revision_info(Revision_info)
      true
    else
      false
    end
  end

  #validates the model. Used in lib/task/cbrain_model_validation.rake
  def self.check(checks_to_run)

    #Run sanity checks if it has never has been run
    #-----------------------------------------------------------------------------
    puts "C> CBRAIN BrainPortal database sanity check started, " + Time.now.to_s
    #-----------------------------------------------------------------------------
    
    begin
      #Where the magic happens
      #Run all methods in this class starting with ensure_
      super #calling super to run the actual checks
      puts "C> \t- Adding new sanity check record."
      SanityCheck.new(:revision_info => Revision_info).save! #Adding new SanityCheck record
      
      #-----------------------------------------------------------------------------
      # Rescue: for the cases when the Rails application is started as part of
      # a DB migration.
      #-----------------------------------------------------------------------------
    rescue => error
      
      if error.to_s.match(/Mysql::Error.*Table.*doesn't exist/i)
        puts "C> Skipping validation:"
        puts "C> \t- Database table doesn't exist yet. It's likely this system is new and the migrations have not been run yet."
      elsif error.to_s.match(/Mysql::Error: Unknown column/i)
        puts "C> Skipping validation:"
        puts "C> \t- Some database table is missing a column. It's likely that migrations aren't up to date yet."
      elsif error.to_s.match(/Unknown database/i)
        puts "C> Skipping validation:"
        puts "C> \t- System database doesn't exist yet. It's likely this system is new and the migrations have not been run yet."
      else
        raise
      end

    end

  end


   
  ####################################################
  # Add new validations below                        #
  #                                                  #
  # example:                                         #
  #                                                  #
  # def ensure_that_something_is_true                #
  #   Something.new()                                #
  #   unless something.is_true? something.make_true! #
  # end                                              #
  #                                                  #
  ####################################################
  
  #Creates the everyone group and adds the admin user if it does not exist
  def self.ensure_001_group_and_users_have_been_created
    
    #-----------------------------------------------------------------------------
    puts "C> Ensuring that required groups and users have been created..."
    #-----------------------------------------------------------------------------

    everyone_group = Group.find_by_name("everyone")
    if ! everyone_group
      puts "C> \t- SystemGroup 'everyone' does not exist. Creating it."
      everyone_group = SystemGroup.create!(:name  => "everyone")
    elsif ! everyone_group.is_a?(SystemGroup)
      puts "C> \t- Group 'everyone' migrated to SystemGroup."
      everyone_group.type = 'SystemGroup'
      everyone_group.save!
    end

    unless User.find(:first, :conditions => {:login  => 'admin'})
      puts "C> \t- Admin user does not exist yet. Creating one."
      
      pwdduh = 'cbrainDuh' # use 9 chars for pretty warning message below.
      User.create!(
                   :full_name             => "Admin",
                   :login                 => "admin",
                   :password              => pwdduh,
                   :password_confirmation => pwdduh,
                   :email                 => 'admin@here',
                   :role                  => 'admin'
                   )
      puts("C> ******************************************************")
      puts("C> *  USER 'admin' CREATED WITH PASSWORD '#{pwdduh}'    *")
      puts("C> * CHANGE THIS PASSWORD IMMEDIATELY AFTER FIRST LOGIN *")
      puts("C> ******************************************************")
    end
  end
  


  #adds everyone to the everyone group 
  def self.ensure_002_users_belongs_to_everyone_group

    #-----------------------------------------------------------------------------
    puts "C> Ensuring that all users have their own group and belong to 'everyone'..."
    #-----------------------------------------------------------------------------

    everyone_group=Group.find_by_name('everyone')
    User.find(:all, :include => [:groups, :user_preference]).each do |u|
      unless u.group_ids.include? everyone_group.id
        puts "C> \t- User #{u.login} doesn't belong to group 'everyone'. Adding them."
        groups = u.group_ids
        groups << everyone_group.id
        u.group_ids = groups
        u.save!
      end
      
      user_group = Group.find_by_name(u.login)
      if ! user_group
        puts "C> \t- User #{u.login} doesn't have their own system group. Creating one."
        user_group = UserGroup.create!(:name  => u.login)
        u.groups  << user_group
        u.save!
      elsif ! user_group.is_a?(UserGroup)
        puts "C> \t- '#{user_group.name}' group migrated to class UserGroup."
        user_group.type = 'UserGroup'
        user_group.save!
      end
      if user_group.users != [u]
        puts "C> \t- '#{user_group.name}' group not used for user '#{u.login}'. Resetting user list."
        user_group.users = [u]
        user_group.save!
      end
      
      unless u.user_preference
        puts "C> \t- User #{u.login} doesn't have a user preference resource. Creating one."
        UserPreference.create!(:user_id => u.id)
      end
    end
  end



  #Makes sure that all sites belong to a group and that users of that site belong to it
  def self.ensure_that_all_sites_have_a_group_and_that_all_their_users_belong_to_it

    #-----------------------------------------------------------------------------
    puts "C> Ensuring that all sites have a group and that all their users belong to it..."
    #-----------------------------------------------------------------------------

    Site.all.each do |s|
      site_group = Group.find_by_name(s.name)
      if ! site_group
        puts "C> \t- Site #{s.name} doesn't have their own site group. Creating one."
        site_group = SiteGroup.create!(:name  => s.name, :site_id => s.id)
      elsif ! site_group.is_a?(SiteGroup)
        puts "C> \t- '#{site_group.name}' group migrated to class SiteGroup."
        site_group.type = 'SiteGroup'
        site_group.save!
      end
      if site_group.site != s
        puts "C> \t- '#{site_group.name}' group doesn't have site set to #{s.name}. Resetting it."
        site_group.site = s
        site_group.save!
      end
      
      unless s.user_ids.sort == site_group.user_ids.sort
        puts "C> \t- '#{site_group.name}' group user list does not match site user list. Resetting users."
        site_group.user_ids = s.user_ids
      end
    end

  end
  


  #Groups must have a type like WorkGroup, SystemGroup...
  def self.ensure_that_all_groups_have_a_type

    #-----------------------------------------------------------------------------
    puts "C> Ensuring that all groups have a type..."
    #-----------------------------------------------------------------------------

    Group.all.each do |g|
      next if g.type
      puts "C> \t- '#{g.name}' group migrated to WorkGroup."
      g.type = 'WorkGroup'
      g.save!
    end

  end



  #Userfiles must belong to a group or everyone
  def self.ensure_that_all_userfiles_have_a_group

    #-----------------------------------------------------------------------------
    puts "C> Ensuring that userfiles all have a group..."
    #-----------------------------------------------------------------------------

    missing_gid = Userfile.find(:all, :conditions => { :group_id => nil })
    missing_gid.each do |file|
      user   = file.user
      raise "Error: cannot find a user for file '#{file.id}' ?!?" unless user
      ugroup = SystemGroup.find_by_name(user.login)
      raise "Error: cannot find a SystemGroup for user '#{user.login}' ?!?" unless ugroup
      puts "C> \t- Adjusted file '#{file.name}' to group '#{ugroup.name}'."
      file.group = ugroup
      file.save!
    end
    
  end
  


  #Makes sure that the portal is registered as a remote ressource or adds it
  def self.ensure_that_rails_app_is_a_remote_resource

     #-----------------------------------------------------------------------------
     puts "C> Ensuring that this RAILS app is registered as a RemoteResource..."
     #-----------------------------------------------------------------------------

     dp_cache_md5 = DataProvider.cache_md5
     brainportal  = BrainPortal.find(:first,
                                     :conditions => { :cache_md5 => dp_cache_md5 })
 
     unless brainportal
       puts "C> \t- Creating a new BrainPortal record for this RAILS app."
       admin  = User.find_by_login('admin')
       gadmin = Group.find_by_name('admin')
       brainportal = BrainPortal.create!(
                                         :name        => "Portal_" + rand(10000).to_s,
                                         :user_id     => admin.id,
                                         :group_id    => gadmin.id,
                                         :online      => true,
                                         :read_only   => false,
                                         :description => 'CBRAIN BrainPortal on host ' + Socket.gethostname,
                                         :cache_md5   => dp_cache_md5 )
       puts "C> \t- NOTE: You might want to use the console and give it a better name than '#{brainportal.name}'."
     end

   end


  
  #cleans up old syncstatus that are left in the database 
  def self.ensure_syncstatus_is_clean

    #-----------------------------------------------------------------------------
    puts "C> Cleaning up old SyncStatus objects..."
    #-----------------------------------------------------------------------------

    rr_ids = RemoteResource.all.index_by { |rr| rr.id }
    ss_deleted = 0
    SyncStatus.all.each do |ss|
      ss_rr_id = ss.remote_resource_id
      if ss_rr_id.blank? || ! rr_ids[ss_rr_id]
        if (ss.destroy rescue false)
          ss_deleted += 1
        end
      end
    end
    if ss_deleted > 0
      puts "C> \t- Removed #{ss_deleted} old SyncStatus objects."
    else
      puts "C> \t- No old SyncStatus objects to delete."
    end
  end
  


  #Custom filters must have a type or be of type UserfileCustomFilter
  def self.ensure_custom_filters_have_a_type

    #-----------------------------------------------------------------------------
    puts "C> Ensuring custom filters have a type..."
    #-----------------------------------------------------------------------------

    if CustomFilter.column_names.include?("type")
      CustomFilter.all.each do |cf|
        if cf.class == CustomFilter
          puts "C> \t- Giving filter #{cf.name} the type 'UserfileCustomFilter'."
          cf.type = 'UserfileCustomFilter'
          cf.save!
        end
      end
    end
  end

end





