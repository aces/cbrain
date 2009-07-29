
#
# CBRAIN Project
#
# User model
#
# Original author: restful authentication plugin
# Modified by: Tarek Sherif
#
# $Id$
#

require 'digest/sha1'

#Model representing CBrain users. 
#All authentication of user access to the system is handle by the User model.
#User level access to pages are handled through a given user's +role+ (either *admin* or *user*).
#
#=Attributes:
#[*full_name*] The full name of the user.
#[*login*] The user's login ID.
#[*email*] The user's e-mail address.
#[*role*]  The user's role.
#= Associations:
#*Has* *many*:
#* Userfile
#* CustomFilter
#* Tag
#* Feedback
#*Has* *one*:
#* UserPreference
#*Has* *and* *belongs* *to* *many*:
#* Group
#
#=Dependencies
#[<b>On Create<b>] Creating a user will create an associated UserPreference
#                  resource.
#[<b>On Destroy<b>] A user cannot be destroyed if it is still associated with any
#                   Userfile, RemoteResource or DataProvider resources.
#                   Destroying a user will destroy the associated UserPreference,
#                   Tag, Feedback and CustomFilter resources.
class User < ActiveRecord::Base

  Revision_info="$Id$"

  has_many                :userfiles
  has_many                :data_providers
  has_many                :remote_resources
  has_and_belongs_to_many :groups

  #The following resources should be destroyed when a given user is destroyed.
  has_many                :tags,            :dependent => :destroy
  has_many                :feedbacks,       :dependent => :destroy
  has_one                 :user_preference, :dependent => :destroy
  has_many                :custom_filters,  :dependent => :destroy

  
  
  # Virtual attribute for the unencrypted password
  attr_accessor :password #:nodoc:

  validates_presence_of     :full_name, :login, :email, :role
  validates_presence_of     :password,                   :if => :password_required?
  validates_presence_of     :password_confirmation,      :if => :password_required?
  validates_length_of       :password, :within => 4..40, :if => :password_required?
  validates_confirmation_of :password,                   :if => :password_required?
  validates_length_of       :login,    :within => 3..40
  validates_length_of       :email,    :within => 3..100
  validates_uniqueness_of   :login, :email, :case_sensitive => false
  validate_on_create        :prevent_group_collision
  
  before_create             :create_user_preference
  before_save               :encrypt_password
  before_destroy            :validate_destroy
    
  # prevents a user from submitting a crafted form that bypasses activation
  # anything else you want your user to change should be added here.
  attr_accessible :full_name, :login, :email, :password, :password_confirmation, :role, :group_ids

  # Authenticates a user by their login name and unencrypted password.  Returns the user or nil.
  def self.authenticate(login, password)
    u = find_by_login(login) # need to get the salt
    u && u.authenticated?(password) ? u : nil
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
    save(false)
  end

  def forget_me #:nodoc:
    self.remember_token_expires_at = nil
    self.remember_token            = nil
    save(false)
  end

  # Returns true if the user has just been activated.
  def recently_activated? #:nodoc:
    @activated
  end
  
  #Does this user's role match +role+.
  def has_role?(role)
    return self.role == role.to_s
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
   
  def prevent_group_collision #:nodoc:
    if self.login && (WorkGroup.find_by_name(self.login) || self.login == 'everyone') 
      errors.add(:login, "already in use by a group.")
    end
  end
  
  def create_user_preference #:nodoc:
    self.build_user_preference
  end
  
  #Ensure that the system will be in a valid state if this user is destroyed.
  def validate_destroy
    if self.login == 'admin'
      raise "Default admin user cannot be destroyed."
    end
    unless self.userfiles.empty?
      raise "User #{self.login} cannot be destroyed while there are still files on the account."
    end
    unless self.data_providers.empty?
      raise "User #{self.login} cannot be destroyed while there are still data providers on the account."
    end
    unless self.remote_resources.empty?
      raise "User #{self.login} cannot be destroyed while there are still remote resources on the account."
    end
    destroy_system_group
  end
  
  def destroy_system_group #:nodoc:
    system_group = SystemGroup.find(:first, :conditions => {:name => self.login})
    system_group.destroy if system_group
  end
end
