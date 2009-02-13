
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
class User < ActiveRecord::Base

  Revision_info="$Id$"

  has_many                :userfiles
  has_many                :managed_groups,
                          :class_name => 'Group',
                          :foreign_key => 'manager_id',
                          :dependent => :nullify
  has_and_belongs_to_many :groups
  has_many                :tags
  has_many                :feedbacks
  
  
  # Virtual attribute for the unencrypted password
  attr_accessor :password

  validates_presence_of     :full_name, :login, :email, :role
  validates_presence_of     :password,                   :if => :password_required?
  validates_presence_of     :password_confirmation,      :if => :password_required?
  validates_length_of       :password, :within => 4..40, :if => :password_required?
  validates_confirmation_of :password,                   :if => :password_required?
  validates_length_of       :login,    :within => 3..40
  validates_length_of       :email,    :within => 3..100
  validates_uniqueness_of   :login, :email, :case_sensitive => false
  before_save :encrypt_password
    
  # prevents a user from submitting a crafted form that bypasses activation
  # anything else you want your user to change should be added here.
  attr_accessible :full_name, :login, :email, :password, :password_confirmation, :role, :group_ids

  # Authenticates a user by their login name and unencrypted password.  Returns the user or nil.
  def self.authenticate(login, password)
    u = find_by_login(login) # need to get the salt
    u && u.authenticated?(password) ? u : nil
  end

  # Encrypts some data with the salt.
  def self.encrypt(password, salt)
    Digest::SHA1.hexdigest("--#{salt}--#{password}--")
  end

  # Encrypts the password with the user salt
  def encrypt(password)
    self.class.encrypt(password, salt)
  end

  def authenticated?(password)
    crypted_password == encrypt(password)
  end

  def remember_token?
    remember_token_expires_at && Time.now.utc < remember_token_expires_at 
  end

  # These create and unset the fields required for remembering users between browser closes
  def remember_me
    remember_me_for 2.weeks
  end

  def remember_me_for(time)
    remember_me_until time.from_now.utc
  end

  def remember_me_until(time)
    self.remember_token_expires_at = time
    self.remember_token            = encrypt("#{email}--#{remember_token_expires_at}")
    save(false)
  end

  def forget_me
    self.remember_token_expires_at = nil
    self.remember_token            = nil
    save(false)
  end

  # Returns true if the user has just been activated.
  def recently_activated?
    @activated
  end
  
  def has_role?(role)
    return self.role == role.to_s
  end
  
  def vault_dir
    Pathname.new(CBRAIN::Filevault_dir) + self.login
  end

  protected
    # before filter 
    def encrypt_password
      return if password.blank?
      self.salt = Digest::SHA1.hexdigest("--#{Time.now.to_s}--#{login}--") if new_record?
      self.crypted_password = encrypt(password)
    end
      
    def password_required?
      crypted_password.blank? || !password.blank?
    end
    
    def after_create
      userdir = Pathname.new(CBRAIN::Filevault_dir) + self.login
      Dir.mkdir(userdir.to_s) unless File.directory?(userdir.to_s)
    end
    
    def before_destroy
      self.userfiles.destroy_all
      userdir = Pathname.new(CBRAIN::Filevault_dir) + self.login
      Dir.rmdir(userdir.to_s) if File.directory?(userdir.to_s)
    end
end
