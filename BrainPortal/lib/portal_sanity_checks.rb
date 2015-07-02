
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

require 'socket'

# Sanity library for BrainPortal
#
# Original author: Nicolas Kassis
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
class PortalSanityChecks < CbrainChecker #:nodoc:

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Checks to see if the validation was run since last change
  def self.done? #:nodoc:
    if SanityCheck.find_by_revision_info(Revision_info.to_s)
      true
    else
      false
    end
  end

  # validates the model. Used in lib/task/cbrain_model_validation.rake
  def self.check(checks_to_run) #:nodoc:

    #Run sanity checks if it has never has been run
    #-----------------------------------------------------------------------------
    puts "C> CBRAIN BrainPortal database sanity check started, " + Time.now.to_s
    #-----------------------------------------------------------------------------

    begin
      #Where the magic happens
      #Run all methods in this class starting with ensure_
      super #calling super to run the actual checks
      puts "C> \t- Adding new sanity check record."
      SanityCheck.new(:revision_info => Revision_info.to_s).save! #Adding new SanityCheck record

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

  # Creates the everyone group and adds the admin user if it does not exist
  def self.ensure_001_group_and_users_have_been_created #:nodoc:

    #-----------------------------------------------------------------------------
    puts "C> Ensuring that required groups and users have been created..."
    #-----------------------------------------------------------------------------

    everyone_group = Group.everyone
    if ! everyone_group
      puts "C> \t- SystemGroup 'everyone' does not exist."
      puts "C> \t  Please run 'rake db:seed RAILS_ENV=#{Rails.env}' to create it."
      Kernel.exit(10)
    end

    unless User.where( :login  => 'admin' ).first
      puts "C> \t- Admin user does not exist."
      puts "C> \t  Please run 'rake db:seed RAILS_ENV=#{Rails.env}' to create it."
      Kernel.exit(10)
    end
  end



  # adds everyone to the everyone group
  def self.ensure_002_users_belongs_to_everyone_group #:nodoc:

    #-----------------------------------------------------------------------------
    puts "C> Ensuring that all users have their own group and belong to 'everyone'..."
    #-----------------------------------------------------------------------------

    everyone_group = Group.everyone
    User.includes(:groups).each do |u|
      unless u.group_ids.include? everyone_group.id
        puts "C> \t- User #{u.login} doesn't belong to group 'everyone'. Adding them."
        groups = u.group_ids
        groups << everyone_group.id
        u.group_ids = groups
        u.save!
      end

      user_group = u.own_group
      if ! user_group
        puts "C> \t- User #{u.login} doesn't have its own system group. Creating one."
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
    end
  end



  # Makes sure that all sites belong to a group and that users of that site belong to it
  def self.ensure_that_all_sites_have_a_group_and_that_all_their_users_belong_to_it #:nodoc:

    #-----------------------------------------------------------------------------
    puts "C> Ensuring that all sites have a group and that all their users belong to it..."
    #-----------------------------------------------------------------------------

    Site.all.each do |s|
      site_group = s.own_group
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



  # Groups must have a type like WorkGroup, SystemGroup...
  def self.ensure_that_all_groups_have_a_type #:nodoc:

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



  # Userfiles must belong to a group or everyone
  def self.ensure_that_all_userfiles_have_a_group #:nodoc:

    #-----------------------------------------------------------------------------
    puts "C> Ensuring that userfiles all have a group..."
    #-----------------------------------------------------------------------------

    missing_gid = Userfile.where( :group_id => nil )
    missing_gid.each do |file|
      user   = file.user
      raise "Error: cannot find a user for file '#{file.id}' ?!?" unless user
      ugroup = user.own_group
      raise "Error: cannot find a SystemGroup for user '#{user.login}' ?!?" unless ugroup
      puts "C> \t- Adjusted file '#{file.name}' to group '#{ugroup.name}'."
      file.group = ugroup
      file.save!
    end

  end



  # ToolConfigs must belong to a group or everyone
  def self.ensure_that_all_toolconfigs_have_a_group #:nodoc:

    #-----------------------------------------------------------------------------
    puts "C> Ensuring that toolconfigs all gave a group..."
    #-----------------------------------------------------------------------------

    everyone_group = Group.everyone
    missing_gid    = ToolConfig.where( :group_id => nil )
    missing_gid.each do |tc|
      tc.group_id = everyone_group.id
      tc.save!
    end

  end



  # Makes sure that the portal is registered as a remote ressource or adds it
  def self.ensure_that_rails_app_is_a_remote_resource #:nodoc:

    #-----------------------------------------------------------------------------
    puts "C> Ensuring that this RAILS app is registered as a RemoteResource..."
    #-----------------------------------------------------------------------------

    myname       = ENV["CBRAIN_RAILS_APP_NAME"]
    myname     ||= CBRAIN::CBRAIN_RAILS_APP_NAME if CBRAIN.const_defined?('CBRAIN_RAILS_APP_NAME')

    brainportal  = myname ? BrainPortal.find_by_name(myname) : nil

    if ! brainportal
      puts "C> \t- There is no BrainPortal record for this RAILS app."
      puts "C> \t  Please run 'rake db:seed RAILS_ENV=#{Rails.env}' to create one."
      Kernel.exit(10)
    end

    cache_ok = DataProvider.this_is_a_proper_cache_dir!(brainportal.dp_cache_dir, :for_remote_resource_id => brainportal.id) rescue nil
    unless cache_ok
      puts "C> \t- NOTE: You need to use the interface to configure properly the Data Provider cache directory."
    end

  end



  # Custom filters must have a type or be of type UserfileCustomFilter
  def self.ensure_custom_filters_have_a_type #:nodoc:

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

  # Each tags should have a group
  def self.ensure_tags_have_a_group_id #:nodoc:

    #-----------------------------------------------------------------------------
    puts "C> Ensuring tags have a group..."
    #-----------------------------------------------------------------------------

    tags = Tag.all(:conditions => "group_id IS NULL")
    tags.each do |t|
      new_group = t.user.own_group
      t.group_id = new_group.id
      t.save!
    end
  end

  # Each groups should have a creator
  def self.ensure_groups_have_creator_id #:nodoc:

    #-----------------------------------------------------------------------------
    puts "C> Ensuring groups have a creator_id..."
    #-----------------------------------------------------------------------------

    admin_user = User.find_by_login("admin")

    Group.all.each do |g|
      if g.creator_id.nil?
        g.creator_id = admin_user.id
        g.save!
        puts "C> \t- Group '#{g.name}' had creator set to 'admin'"
      end
    end
  end

end

