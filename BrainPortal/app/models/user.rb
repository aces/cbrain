
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
# * Feedback
# *Has* *and* *belongs* *to* *many*:
# * Group
#
# =Dependencies
# [<b>On Destroy</b>] A user cannot be destroyed if it is still associated with any
#                     Userfile, RemoteResource or DataProvider resources.
#                     Destroying a user will destroy the associated
#                     Tag, Feedback and CustomFilter resources.
class User < ActiveRecord::Base

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
                            :filename_format => true

  validates                 :password,
                            :length => { :minimum => 8 },
                            :confirmation => true,
                            :presence => true,
                            :if => :password_required?

  validates                 :type,
                            :subclass => true

  validates_presence_of     :password_confirmation,      :if => :password_required?

  validates                 :email,
                            :format => { :with => /^(\w[\w\-\.]*)@(\w[\w\-]*\.)+[a-z]{2,}$|^\w+@localhost$/i },
                            :allow_blank => true

  validate                  :immutable_login,            :on => :update
  validate                  :password_strength_check,    :if => :password_required?

  before_create             :add_system_groups
  before_save               :encrypt_password
  before_save               :destroy_sessions_if_locked
  after_update              :system_group_site_update
  after_destroy             :destroy_system_group
  after_destroy             :destroy_user_sessions

  # The following resources PREVENT the user from being destroyed if some of them exist.
  has_many                :userfiles,         :dependent => :restrict
  has_many                :data_providers,    :dependent => :restrict
  has_many                :remote_resources,  :dependent => :restrict
  has_many                :cbrain_tasks,      :dependent => :restrict

  has_and_belongs_to_many :groups
  belongs_to              :site

  # The following resources are destroyed automatically when the user is destroyed.
  has_many                :messages,        :dependent => :destroy
  has_many                :tools,           :dependent => :destroy
  has_many                :tags,            :dependent => :destroy
  has_many                :feedbacks,       :dependent => :destroy
  has_many                :custom_filters,  :dependent => :destroy
  has_many                :exception_logs,  :dependent => :destroy

  # prevents a user from submitting a crafted form that bypasses activation
  # anything else you want your user to change should be added here.
  attr_accessible :full_name, :email, :password, :password_confirmation, :time_zone, :city, :country

  force_text_attribute_encoding 'UTF-8', :full_name, :city, :country

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

  def signed_license_agreements(license_agreement_set=self.license_agreement_set) #:nodoc:
    current_user_license = self.meta[:signed_license_agreements] || []

    return current_user_license if current_user_license.empty?

    extra_license = current_user_license - license_agreement_set
    self.meta[:signed_license_agreements] =  current_user_license  - extra_license
    self.save
    self.meta[:signed_license_agreements] || []
  end

  def unsigned_license_agreements #:nodoc:
    license_agreement_set = self.license_agreement_set

    # Difference between all license agreements and whom signed by the user
    license_agreement_set - self.signed_license_agreements(license_agreement_set)
  end

  def license_agreement_set #:nodoc:
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

  def all_licenses_signed #:nodoc:
    self.meta.reload
    self.meta[:all_licenses_signed]
  end

  def all_licenses_signed=(x) #:nodoc:
    self.meta.reload
    self.meta[:all_licenses_signed] = x
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
    plain_crypted_password = crypted_password.sub(/^\w+:/,"")
    # Changed encryption type if crypted_password is in sha1 or in pbkdf2 (old convention)
    if (password_type(crypted_password) == :sha1   && plain_crypted_password == encrypt_in_sha1(password)) ||
       (password_type(crypted_password) == :pbkdf2 && plain_crypted_password == encrypt_in_pbkdf2(password))
      self.password = password # not a real attribute; only used by encrypt_password() below
      self.encrypt_password()  # explicit call to compute the crypted password (stored as a real rails attribute)
      self.password   = nil    # zap pseudo-attribute for security
      self.save
      true
    # This is now the default CBRAIN encryption mode
    elsif password_type(crypted_password) == :pbkdf2_sha1 # Just check that it matches the PBKDF2 with digest SHA1
      plain_crypted_password == encrypt_in_pbkdf2_sha1(password)
    else
      false
    end
  end

  # Create a random password (to be sent for resets).
  def set_random_password
    s = self.class.random_string
    self.password = s
    self.password_confirmation = s
  end

  # Try to define password type (sha1 or pbkdf2)
  def password_type(crypted_password)
    if crypted_password =~ /^(\w+):/               # "PBKDF2_SHA1:a2c2646186828474b754591a547c18f132d88d744c152655a470161a1a052135"
      Regexp.last_match[1].downcase.to_sym
    elsif crypted_password.size == 40              # "547c18f132d88d744c152655a470161a1a052135"
      :sha1
    elsif crypted_password.size == 64              # "a2c2646186828474b754591a547c18f132d88d744c152655a470161a1a052135"
      :pbkdf2
    else
      nil
    end
  end

  ###############################################
  #
  # Encryption methods
  #
  ###############################################

  # Old encrypt methods
  # Encrypts some data with the salt.
  def self.encrypt(password, salt) #:nodoc:
    encrypt_in_pbkdf2(password,salt)
  end

  # Encrypts the password with the user salt
  def encrypt(password) #:nodoc:
    self.class.encrypt(password, salt)
  end


  # Encrypt methods in sha1
  # Encrypts some data with the salt.
  def self.encrypt_in_sha1(password, salt) #:nodoc:
    Digest::SHA1.hexdigest("--#{salt}--#{password}--")
  end

  # Encrypts the password with the user salt
  def encrypt_in_sha1(password) #:nodoc:
    self.class.encrypt_in_sha1(password, salt)
  end


  # Encrypt methods in PBKDF2
  # Encrypts some data with the salt.
  def self.encrypt_in_pbkdf2(password, salt) #:nodoc:
    PBKDF2.new(:password => password, :salt => salt, :iterations => 10000).hex_string
  end

  # Encrypts the password with the user salt
  def encrypt_in_pbkdf2(password) #:nodoc:
    self.class.encrypt_in_pbkdf2(password, salt)
  end

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

  # Returns the list of groups available to this user based on role.
  def available_groups
    cb_error "#available_groups called from User base class! Method must be implemented in a subclass."
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

  # Returns the IDs of the groups this user
  # is a member of.
  def cached_group_ids
    @_cached_gids ||= self.group_ids
  end

  # Destroy all sessions for user
  def destroy_user_sessions
    myid = self.id
    return true unless myid # defensive
    sessions = CbrainSession.all.select do |s|
      data = s.data rescue {} # old sessions can have problems being reconstructed
      (s.user_id && s.user_id == myid) ||
      (data && data[:user_id] && data[:user_id] == myid)
    end
    sessions.each do |s|
      s.destroy rescue true
    end
    true
  end

  protected

  # "before save" callback; whenever the record is saved, if the 'password'
  # pseudo-attribute is set it will:
  # 1- generate a salt
  # 2- encrypt the password with the salt and
  # 3- save it in crypted_password
  def encrypt_password #:nodoc:
    return true if password.blank?
    self.salt             = Digest::SHA1.hexdigest("--#{Time.now.to_s}--#{login}--") if salt.blank?
    self.crypted_password = "pbkdf2_sha1:" + encrypt_in_pbkdf2_sha1(password)
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

  def password_required? #:nodoc:
    crypted_password.blank? || !password.blank?
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
        new_site.own_group.users << self
      end
    end
  end

  def password_strength_check #:nodoc:
    score = 0
    unless self.password.blank?
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

end
