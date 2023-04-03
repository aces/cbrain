
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

require 'digest/sha1'
require 'pbkdf2'

# Model representing CBrain users.
# All authentication of user access to the system is handle by the User model.
# User level access to pages are handled through a given user's +class+ (currently *NormalUser*, *SiteManager*, *AdminUser*).
#
# =Attributes:
# [*full_name*] The full name of the user.
# [*login*] The user's login ID.
# [*email*] The user's e-mail address.
# = Associations:
# *Has* *many*:
# * Userfile
# * CustomFilter
# * Tag
# *Has* *and* *belongs* *to* *many*:
# * Group
#
# =Dependencies
# [<b>On Destroy</b>] A user cannot be destroyed if it is still associated with any
#                     Userfile, RemoteResource or DataProvider resources.
#                     Destroying a user will destroy the associated
#                     Tag and CustomFilter resources.
class User < ApplicationRecord

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  cbrain_abstract_model! # objects of this class are not to be instanciated

  # Virtual attribute for the unencrypted password
  attr_accessor             :password #:nodoc:

  validates                 :full_name,
                            :presence => true

  validates                 :login,
                            :length => { :within => 3..40 },
                            :uniqueness => {:case_sensitive => false},
                            :presence => true,
                            :username_format => true

  validates                 :password,
                            :length => { :minimum => 8 },
                            :confirmation => true,
                            :presence => true,
                            :if => :password_required?

  validates                 :type,
                            :subclass => true

  validates_presence_of     :password_confirmation,      :if => :password_required?

  validates                 :email,
                            :format => { :with => /\A(\w[\w\-\.]*)@(\w[\w\-]*\.)+[a-z]{2,}\z|\A\w+@localhost\z/i },
                            :allow_blank => true

  validate                  :immutable_login,            :on => :update
  validate                  :password_strength_check,    :if => :password_required?

  before_create             :add_system_groups
  before_save               :encrypt_password
  before_save               :destroy_sessions_if_locked
  before_save               :apply_access_profiles
  after_update              :system_group_site_update
  after_destroy             :destroy_system_group
  after_destroy             :destroy_user_sessions
  after_destroy             :destroy_user_ssh_key

  # The following resources PREVENT the user from being destroyed if some of them exist.
  has_many                :userfiles,         :dependent => :restrict_with_exception
  has_many                :data_providers,    :dependent => :restrict_with_exception
  has_many                :remote_resources,  :dependent => :restrict_with_exception
  has_many                :cbrain_tasks,      :dependent => :restrict_with_exception
  # The following resources are destroyed automatically when the user is destroyed.
  has_many                :messages,        :dependent => :destroy
  has_many                :tools,           :dependent => :destroy
  has_many                :tags,            :dependent => :destroy
  has_many                :custom_filters,  :dependent => :destroy
  has_many                :exception_logs,  :dependent => :destroy
  # Resource usage is kept forever even if account is destroyed.
  has_many                :resource_usage

  has_and_belongs_to_many :access_profiles
  has_and_belongs_to_many :groups
  has_and_belongs_to_many :editable_groups, :class_name => 'Group', join_table: "groups_editors", before_add: :can_be_editor_of!

  belongs_to              :site, :optional => true
  has_one                 :signup

  api_attr_visible :login, :full_name, :email, :type, :site_id, :time_zone, :city, :last_connected_at, :account_locked

  # Returns the admin user
  def self.admin
    @@admin ||= self.find_by_login("admin")
  end

  # Returns all users with admin privileges.
  def self.all_admins(reset = false)
    if reset
      @@all_admins = AdminUser.all
    end

    @@all_admins ||= AdminUser.all
  end

  # Alias for login.
  def name
    self.login
  end

  ###############################################
  #
  # Licensing methods
  #
  ###############################################

  def signed_license_agreements(license_agreement_set=self.license_agreement_set) #:nodoc:
    current_user_license = self.meta[:signed_license_agreements] || []

    return current_user_license if current_user_license.empty?

    extra_license = current_user_license - license_agreement_set
    self.meta[:signed_license_agreements] =  current_user_license  - extra_license
    self.save
    self.meta[:signed_license_agreements] || []
  end

  def cbrain_unsigned_license_agreements #:nodoc:
    # Difference between all cbrain license agreements and signed by the user
    cbrain_license_agreement_set - (strip_prefix signed_license_agreements)
  end

  def neurohub_unsigned_license_agreements #:nodoc:
    neurohub_license_agreement_set - (add_prefix signed_license_agreements)
  end

  # all h and cbrain agreements (on accessible objects)
  def license_agreement_set
    all_object_with_license = RemoteResource.find_all_accessible_by_user(self) +
                              Tool.find_all_accessible_by_user(self) +
                              DataProvider.find_all_accessible_by_user(self)

    license_agreements = []
    # List all license_agreements
    all_object_with_license.each do |o|
      o_license_agreements = o.meta[:license_agreements]
      license_agreements.concat(o_license_agreements) if o_license_agreements
    end

    RemoteResource.current_resource.license_agreements  + license_agreements
  end

  # cbrain required licenses
  def cbrain_license_agreement_set
    license_agreement_set.reject {|l| l.start_with?('nh-')}
  end

  # neurohub license agreement set
  def neurohub_license_agreement_set
    RemoteResource.current_resource.license_agreements.select {|l| l.start_with?('nh-')}
  end

  # a flag that all required cbrain licenses are signed
  def all_licenses_signed #:nodoc:
    self.meta.reload
    self.meta[:all_licenses_signed]
  end

  def all_licenses_signed=(x) #:nodoc:
    self.meta.reload
    self.meta[:all_licenses_signed] = x
  end

  # neurohub specific licenses are signed flag
  def neurohub_licenses_signed #:nodoc:
    self.meta.reload
    self.meta['neurohub_licenses_signed']
  end

  # neurohub specific licenses are signed flag setter
  def neurohub_licenses_signed=(x) #:nodoc:
    self.meta.reload
    self.meta['neurohub_licenses_signed'] = x
  end

  def accept_license_agreement(license)  # logs and saves signed agreement id (either on cbrain or neurohub side)
    signed_agreements = self.meta[:signed_license_agreements] || []
    signed_agreements << license
    self.meta[:signed_license_agreements] = signed_agreements
    self.addlog("Signed license agreement '#{@license}'.")
  end


  #############################################################
  #
  # Custom, user-created licenses for misc objects
  #
  #############################################################

  # This function lists custom licenses that user still has to sign in order to access to the object
  def unsigned_custom_licenses(obj)
    obj.custom_license_agreements - self.custom_licenses_signed
  end

  # This function lists all the already signed custom licenses
  def custom_licenses_signed #:nodoc:
    self.meta.reload
    Array(self.meta[:custom_licenses_signed].presence)
  end

  # This function records custom licenses signed by the user.
  def custom_licenses_signed=(licenses) #:nodoc:
    self.meta.reload
    self.meta[:custom_licenses_signed] = Array(licenses)
  end

  # Records that a custom license agreement has
  # been signed by adding it to the list of signed ones.
  def add_signed_custom_license(license_file)
    cb_error "A license file is supposed to be a TextFile" unless license_file.is_a?(TextFile)
    signed  = self.custom_licenses_signed
    signed |= [ license_file.id ]
    signed = TextFile.where(:id => signed).pluck(:id) # clean up dead IDs
    self.custom_licenses_signed = signed
  end

  ###############################################
  #
  # Password and login gestion
  #
  ###############################################

  # Authenticates a user by their login name and unencrypted password. Returns the user or nil.
  def self.authenticate(login, password)
    u = find_by_login(login) rescue nil
    return nil unless u && u.authenticated?(password)
    u
  end

  def authenticated?(password) #:nodoc:
    self.crypted_password == encrypt_in_pbkdf2_sha1(password)
  end

  # Create a random password (to be sent for resets).
  def set_random_password
    s = self.class.random_string
    self.password = s
    self.password_confirmation = s
  end

  ###############################################
  #
  # Encryption methods
  #
  ###############################################

  def self.encrypt_in_pbkdf2_sha1(password, salt) #:nodoc:
    password               = PBKDF2.new(:password => password, :salt => salt, :iterations => 10000)
    password.hash_function = OpenSSL::Digest::SHA1.new
    password.hex_string
  end

  # Encrypts the password with the user salt
  def encrypt_in_pbkdf2_sha1(password) #:nodoc:
    self.class.encrypt_in_pbkdf2_sha1(password, salt)
  end

  ###############################################
  #
  # Permission methods
  #
  ###############################################

  # Does this user's role match +role+?
  def has_role?(role)
    return self.is_a?(role.to_s.classify.constantize)
  end

  ###############################################
  #
  # Group lists
  #
  ###############################################

  # List of groups which provide view access to resources.
  # It is possible for the user not to be a member of one of those groups (e.g. public groups)
  def viewable_groups
    cb_error "#viewable_groups called from User base class! Method must be implemented in a subclass."
  end

  def viewable_group_ids
    viewable_groups.pluck('groups.id')
  end

  # List of groups that the user can list in the interface. Normally, groups that are invisible
  # are not listed.
  def listable_groups
    cb_error "#listable_groups called from User base class! Method must be implemented in a subclass."
  end

  def listable_group_ids
    listable_groups.pluck('groups.id')
  end

  # List of groups that the user can assign to resources.
  def assignable_groups
    cb_error "#assignable_groups called from User base class! Method must be implemented in a subclass."
  end

  def assignable_group_ids
    assignable_groups.pluck('groups.id')
  end

  # List of groups that the user can modify (the group's attributes themselves, not the resources)
  def modifiable_groups
    cb_error "#modifiable_groups called from User base class! Method must be implemented in a subclass."
  end

  def modifiable_group_ids
    modifiable_groups.pluck('groups.id')
  end

  ###############################################
  #
  # Model access lists
  #
  ###############################################

  # Find the tools that this user has access to.
  def available_tools
    cb_error "#available_tools called from User base class! Method must be implemented in a subclass."
  end

  # Find the scientific tools that this user has access to.
  def available_scientific_tools
    self.available_tools.where( :category  => "scientific tool" ).order( "tools.select_menu_text" )
  end

  # Find the conversion tools that this user has access to.
  def available_conversion_tools
    self.available_tools.where( :category  => "conversion tool" ).order( "tools.select_menu_text" )
  end

  # Returns the list of tags available to this user.
  def available_tags
    Tag.where( ["tags.user_id=? OR tags.group_id IN (?)", self.id, self.group_ids] )
  end

  # Returns the list of tasks available to this user.
  def available_tasks
    cb_error "#available_tasks called from User base class! Method must be implemented in a subclass."
  end

  # Return the list of users under this user's control based on role.
  def available_users
    cb_error "#available_users called from User base class! Method must be implemented in a subclass."
  end

  # Return the list of sites accessible to the user
  def accessible_sites
    cb_error "#accessible_sites called from User base class! Method must be implemented in a subclass."
  end

  # Can this user be accessed by +user+?
  def can_be_accessed_by?(user, access_requested = :read) #:nodoc:
    return true if user.has_role? :admin_user
    return true if user.has_role?(:site_manager) && self.site_id == user.site_id
    self.id == user.id
  end

  # Returns the SystemGroup associated with the user; this is a
  # group with the same name as the user.
  def system_group
    @own_group ||= UserGroup.where( :name => self.login ).first
  end

  # An alias for system_group()
  alias own_group system_group

  # Returns true if the user belongs to the +group_id+ (or a Group)
  def is_member_of_group(group_id)
     group_id = group_id.id if group_id.is_a?(Group)
     @group_ids_hash ||= self.group_ids.index_by { |gid| gid }
     @group_ids_hash[group_id] ? true : false
  end

  # Destroy all sessions for user
  def destroy_user_sessions
    LargeSessionInfo.where(:user_id => self.id).destroy_all
  end

  # Returns a SshKey object for the user.
  # If option +create_it+ is true, create the key files if necessary.
  # If option +ok_no_files+ is true, will return the object even if
  # the key files don't exist yet (default it to raise an exception)
  def ssh_key(options = { :create_id => false, :ok_no_files => false })
    name = "u#{self.id}" # Avoiding username in ssh filenames or in comment.
    return SshKey.find_or_create(name) if options[:create_it]
    return SshKey.new(name)            if options[:ok_no_files]
    SshKey.find(name) # will raise exception if files are not there
  end

  # After destroy callback: destroy the user's SSH key on the filesystem, if any.
  def destroy_user_ssh_key
    self.ssh_key.destroy
  rescue
    true
  end

  # Returns the timestamp of last activity, based on session info.
  # Returns nil if no record is found in the LargeSessionInfo table.
  # +active+ can be set to true, false, or [ true, false ] (default).
  def last_activity_at(active = [true, false])
    LargeSessionInfo
      .where(:user_id => self.id, :active => active)
      .order("updated_at desc")
      .limit(1)
      .pluck(:updated_at)
      .first
  end



  ##############################################
  # Zenodo Publishing Support
  ##############################################

  def has_zenodo_credentials? #:nodoc:
    self.zenodo_sandbox_token.present? || self.zenodo_main_token.present?
  end



  ##############################################
  # Access Profiles Adjustments
  ##############################################

  # Returns the list of group IDs
  # from all the AccessProfiles associated with
  # the current user.
  def union_group_ids_from_access_profiles
    aps = self.access_profiles
    gids = aps.inject([]) do |group_ids,ap|
      group_ids += ap.group_ids  # union of all
      group_ids
    end
    gids.uniq
  end

  # Scans the list of AccessProfiles associated
  # with the current user, and makes sure the user
  # is a member of all the groups in all these profiles.
  # "before save" callback, so that if any changes are made
  # to the list of AccessProfiles, the group membership will
  # be properly updated.
  # If a list of +remove_group_ids+ is supplied,
  # the user will be removed from these groups as
  # long as they are not also in any of the AccessProfiles.
  #
  # Ex: given two AccessProfiles with these (overlapping) group IDs:
  #
  #   ap1.group_ids = [ 11, 12, 13, 99,            ]
  #   ap2.group_ids = [             99, 21, 22, 23 ]
  #
  # then assigning these two AccessProfiles and invoking the method:
  #
  #   user.access_profile_ids = [ ap1.id, ap2.id ]
  #   user.apply_access_profiles()
  #
  # will result in the user being added to all 7 groups, exactly as
  # if an assignement was performed like this:
  #
  #   user.group_ids += [ 11, 12, 13, 99, 21, 22, 23 ]
  #
  # To handle the case of AccessProfiles having LOST some group_ids,
  # we can supply a list of removed group_ids in +remove_group_ids+ :
  #
  #   ap1.group_ids = [ 12, 13 ]  # we removed 11 and 99
  #   user.apply_access_profiles( [ 11, 99 ] )
  #
  # will result in the user's list of groups to lose group 11 but NOT
  # group 99, because it's present in ap2.
  def apply_access_profiles(remove_group_ids: [])
    gids = union_group_ids_from_access_profiles
    self.group_ids = (self.group_ids - remove_group_ids + gids).uniq # - and + are NOT COMMUTATIVE!
    true
  end

  def add_editable_groups(groups) #:nodoc:
    groups                   = Array(groups)
    group_ids_to_add         = groups.map { |g| g.is_a?(Group) ? g.id : g.to_i }
    group_ids_to_add         = WorkGroup.where(id: group_ids_to_add).pluck(:id)
    group_ids_to_add        &= self.group_ids
    self.editable_group_ids |= group_ids_to_add
  end

  def remove_editable_groups(groups) #:nodoc:
    groups                   = Array(groups)
    group_ids_to_remove      = groups.map { |g| g.is_a?(WorkGroup) ? g.id : g.to_i }
    self.editable_group_ids -= group_ids_to_remove
  end

  protected

  # "before save" callback; whenever the record is saved, if the 'password'
  # pseudo-attribute is set it will:
  # 1- generate a salt
  # 2- encrypt the password with the salt and
  # 3- save it in crypted_password
  def encrypt_password #:nodoc:
    return true if password.blank?
    if self.salt.present? && self.crypted_password.present? && authenticated?(password) # means the password matches the current hash
      self.errors.add(:password, "cannot be set to be the same as the previous one!")
      throw :abort
    end
    self.salt             = Digest::SHA1.hexdigest("--#{Time.now.to_s}--#{login}--#{rand(999999)}--")
    self.crypted_password = encrypt_in_pbkdf2_sha1(password)
    true
  end

  # "before save" callback, destroy sessions of
  # user if account_locked
  def destroy_sessions_if_locked #:nodoc:
    if self.account_locked &&  # the account is set to be locked ...
       self.changed_attributes.has_key?("account_locked") &&
       self.changed_attributes["account_locked"].blank?   # ... and wasn't locked before the update
      destroy_user_sessions rescue true
    end
    true
  end

  # Returns true if a password pseudo-attribute is present or needed.
  # This is the case when creating a new record, or resetting the password
  # on an existing one.
  def password_required? #:nodoc:
    crypted_password.blank? || salt.blank? || password.present?
  end

  # Create a random string (currently for passwords).
  def self.random_string
    length = rand(5) + 4
    s = ""
    length.times do
      c = rand(75) + 48 # ascii range from '0' to 'z'
      redo if c == 92 || c == 96  # \ or '
      s << c
    end
    s += ("A".."Z").to_a[rand(26)]
    s += ("a".."z").to_a[rand(26)]
    s += ("0".."9").to_a[rand(10)]
    s += ["!", "@", "#", "$", "%", "^", "&", "*"][rand(8)]
    s
  end

  private

  def prevent_group_collision #:nodoc:
    if self.login && SystemGroup.find_by_name(self.login)
      errors.add(:login, "already in use by an existing project.")
    end
  end

  def immutable_login #:nodoc:
    if self.changed.include? "login"
      errors.add(:login, "is immutable.")
    end
  end

  def system_group_site_update  #:nodoc:
    self.own_group.update_attributes(:site_id => self.site_id)

    if self.changed.include?("site_id")
      unless self.changes["site_id"].first.blank?
        old_site = Site.find(self.changes["site_id"].first)
        old_site.own_group.users.delete(self)
      end
      unless self.changes["site_id"].last.blank?
        new_site = Site.find(self.changes["site_id"].last)
        new_site.own_group.user_ids |= [ self.id ]
      end
    end
  end

  def password_strength_check #:nodoc:
    score = 0
    if self.password.present?
      score += 1 if self.password =~ /[A-Z]/
      score += 1 if self.password =~ /[a-z]/
      score += 1 if self.password =~ /\d/
      score += 1 if self.password =~ /[^A-Za-z\d]/
      score += 1 if self.password.length > 14
    end
    if score < 3
      errors.add(:password, "must have three of the following properties: an uppercase letter, a lowercase letter, a digit, a symbol or be at least 15 characters in length")
    end
  end

  # Validation for join table editors_groups
  def can_be_editor_of!(group) #:nodoc:
    group.editor_can_be_added!(self)
  end

  def destroy_system_group #:nodoc:
    system_group = UserGroup.where( :name => self.login ).first
    system_group.destroy if system_group
  end

  def add_system_groups #:nodoc:
    user_group = UserGroup.new(:name => self.login, :site_id  => self.site_id)
    unless user_group.save
      self.errors.add(:base, "User Group: #{user_group.errors.full_messages.join(", ")}")
      return false
    end

    everyone_group = Group.everyone
    group_ids = self.group_ids
    group_ids << user_group.id
    group_ids << everyone_group.id
    if self.site
      site_group = SiteGroup.find_by_name(self.site.name)
      group_ids << site_group.id
    end
    self.group_ids = group_ids
    true
  end

  # strips prefix in a string array
  def strip_prefix(a, prefix='nh-')
    a.map {|l| l.sub(/\A#{prefix}/, "")}
  end

  # add prefix to string array if missing
  def add_prefix(a, prefix='nh-')
    a.map do |l|
      if l.start_with? prefix
        l
      else
        prefix + l
      end
    end
  end

end
