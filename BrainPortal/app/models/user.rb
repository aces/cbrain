
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

#Model representing CBrain users. 
#All authentication of user access to the system is handle by the User model.
#User level access to pages are handled through a given user's +class+ (currently *NormalUser*, *SiteManager*, *AdminUser*).
#
#=Attributes:
#[*full_name*] The full name of the user.
#[*login*] The user's login ID.
#[*email*] The user's e-mail address.
#= Associations:
#*Has* *many*:
#* Userfile
#* CustomFilter
#* Tag
#* Feedback
#*Has* *and* *belongs* *to* *many*:
#* Group
#
#=Dependencies
#[<b>On Destroy</b>] A user cannot be destroyed if it is still associated with any
#                    Userfile, RemoteResource or DataProvider resources.
#                    Destroying a user will destroy the associated 
#                    Tag, Feedback and CustomFilter resources.
class User < ActiveRecord::Base

  Revision_info=CbrainFileRevision[__FILE__]

  # Virtual attribute for the unencrypted password
  attr_accessor :password #:nodoc:

  validates_presence_of     :full_name
  
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
                            
  validates_presence_of     :password_confirmation,      :if => :password_required?
  
  validates                 :email,    
                            :format => { :with => /^(\w[\w\-\.]*)@(\w[\w\-]*\.)+[a-z]{2,}$|^\w+@localhost$/i },
                            :allow_blank => true
                            
  validate                  :immutable_login,            :on => :update
  validate                  :password_strength_check,    :if => :password_required?
  
  before_create             :add_system_groups
  before_save               :encrypt_password
  after_update              :system_group_site_update
  before_destroy            :admin_check
  after_destroy             :destroy_system_group
  after_destroy             :destroy_user_sessions
    
  # prevents a user from submitting a crafted form that bypasses activation
  # anything else you want your user to change should be added here.
  attr_accessible :full_name, :email, :password, :password_confirmation, :time_zone, :city, :country

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

  force_text_attribute_encoding 'UTF-8', :full_name, :city, :country
    
  scope                   :name_like, lambda { |n| {:conditions => ["users.login LIKE ? OR users.full_name LIKE ?", "%#{n}%", "%#{n}%"]} }
    
  #Return the admin user
  def self.admin
    @@admin ||= self.find_by_login("admin")
  end
  
  #Return all users with admin users.
  def self.all_admins
    @@all_admins ||= AdminUser.all
  end
  
  # Authenticates a user by their login name and unencrypted password. Returns the user or nil.
  def self.authenticate(login, password)
    u = find_by_login(login) # need to get the salt
    return nil unless u && u.authenticated?(password)
    u.last_connected_at = Time.now
    u.save
    u
  end
  
  # Alias for login.
  def name
    self.login
  end
  
  def signed_license_agreements
    self.meta[:signed_license_agreements] || []
  end
  
  def unsigned_license_agreements
    RemoteResource.current_resource.license_agreements - self.signed_license_agreements
  end
  
  #Create a random password (to be sent for resets).
  def set_random_password
    s = random_string
    self.password = s
    self.password_confirmation = s
  end

  # Encrypts some data with the salt.
  def self.encrypt(password, salt) #:nodoc:
    Digest::SHA1.hexdigest("--#{salt}--#{password}--")
  end

  # Encrypts the password with the user salt
  def encrypt(password) #:nodoc:
    self.class.encrypt(password, salt)
  end

  def authenticated?(password) #:nodoc:
    crypted_password == encrypt(password)
  end

  def remember_token? #:nodoc:
    remember_token_expires_at && Time.now.utc < remember_token_expires_at 
  end

  # These create and unset the fields required for remembering users between browser closes.
  def remember_me #:nodoc:
    remember_me_for 2.weeks
  end

  def remember_me_for(time) #:nodoc:
    remember_me_until time.from_now.utc
  end

  def remember_me_until(time) #:nodoc:
    self.remember_token_expires_at = time
    self.remember_token            = encrypt("#{email}--#{remember_token_expires_at}")
    save(:validate => false)
  end

  def forget_me #:nodoc:
    self.remember_token_expires_at = nil
    self.remember_token            = nil
    save(:validate => false)
  end
  
  ###############################################
  #
  # Permission methods
  #
  ###############################################
  
  #Does this user's role match +role+?
  def has_role?(role)
    return self.class == role.to_s.classify.constantize
  end
  
  #Does this user have +role+ rights?
  def has_rights?(role)
    return self.is_a? role.to_s.classify.constantize
  end
  
  #Find the tools that this user has access to.
  def available_tools
    cb_error "#available_tools called from User base class! Method must be implement in a subclass."
  end
  
  #Find the scientific tools that this user has access to.
  def available_scientific_tools
    self.available_tools.where( :category  => "scientific tool" ).order( "tools.select_menu_text" )
  end
  
  #Find the conversion tools that this user has access to.
  def available_conversion_tools
    self.available_tools.where( :category  => "conversion tool" ).order( "tools.select_menu_text" )
  end
  
  #Return the list of groups available to this user based on role.
  def available_groups
    cb_error "#available_groups called from User base class! Method must be implement in a subclass."
  end
  
  def available_tags
    Tag.where( ["tags.user_id=? OR tags.group_id IN (?)", self.id, self.group_ids] )
  end
  
  def available_tasks
    cb_error "#available_tasks called from User base class! Method must be implement in a subclass."
  end
  
  #Return the list of users under this user's control based on role.
  def available_users
    cb_error "#available_users called from User base class! Method must be implement in a subclass."
  end

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

  # before filter 
  def encrypt_password #:nodoc:
    return if password.blank?
    self.salt = Digest::SHA1.hexdigest("--#{Time.now.to_s}--#{login}--") if new_record?
    self.crypted_password = encrypt(password)
  end
    
  def password_required? #:nodoc:
    crypted_password.blank? || !password.blank?
  end

  private
  
  #Create a random string (currently for passwords).
  def random_string
    length = rand(4) + 4
    s = ""
    length.times do
      c = rand(75) + 48
      c += 1 if c == 96
      s << c
    end
    s += ("A".."Z").to_a[rand(26)]
    s += ("a".."z").to_a[rand(26)]
    s += ("0".."9").to_a[rand(10)]
    s += ["!", "@", "#", "$", "%", "^", "&", "*"][rand(8)]
    s
  end
   
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
  
  #Ensure that the system will be in a valid state if this user is destroyed.
  def admin_check
    if self.login == 'admin'
      raise CbrainDeleteRestrictionError.new("Default admin user cannot be destroyed.")
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
    user_group = UserGroup.new(:name => self.login, :site  => self.site)
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
