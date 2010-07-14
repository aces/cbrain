
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
#[<b>On Create</b>] Creating a user will create an associated UserPreference
#                   resource.
#[<b>On Destroy</b>] A user cannot be destroyed if it is still associated with any
#                    Userfile, RemoteResource or DataProvider resources.
#                    Destroying a user will destroy the associated UserPreference,
#                    Tag, Feedback and CustomFilter resources.
class User < ActiveRecord::Base

  Revision_info="$Id$"
  has_many                :tools
  has_many                :userfiles
  has_many                :data_providers
  has_many                :remote_resources
  has_many                :messages
  has_many                :cbrain_tasks
  has_and_belongs_to_many :groups
  belongs_to              :site

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
  validates_uniqueness_of   :login, :case_sensitive => false
  validate_on_create        :prevent_group_collision
  validate_on_update        :immutable_login
  validate                  :site_manager_check
  
  before_create             :create_user_preference,
                            :add_system_groups
  before_save               :encrypt_password
  after_update              :system_group_site_update
  before_destroy            :validate_destroy
    
  # prevents a user from submitting a crafted form that bypasses activation
  # anything else you want your user to change should be added here.
  attr_accessible :full_name, :login, :email, :password, :password_confirmation, :role, :group_ids, :site_id, :password_reset

  # Authenticates a user by their login name and unencrypted password.  Returns the user or nil.
  def self.authenticate(login, password)
    u = find_by_login(login) # need to get the salt
    u && u.authenticated?(password) ? u : nil
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
  
  #Does this user's role match +role+?
  def has_role?(role)
    return self.role == role.to_s
  end
  
  #Find the tools that this user has access to.
  def available_tools
    @available_tools ||= if self.has_role? :admin
                         Tool.scoped({})
                       elsif self.has_role? :site_manager
                         Tool.scoped(:conditions  => ["tools.user_id = ? OR tools.group_id IN (?) OR tools.user_id IN (?)", self.id, self.group_ids, self.site.user_ids])
                       else
                         Tool.scoped(:conditions  => ["tools.user_id = ? OR tools.group_id IN (?)", self.id, self.group_ids])
                       end
  end
  #Find the scientific tools that this user has access to.
  def available_scientific_tools
    @available_scientific_tools ||= self.available_tools.scoped(:conditions  => {:category  => "scientific tool"}, :order  => "tools.select_menu_text" )
  end
  
  #Find the conversion tools that this user has access to.
  def available_conversion_tools
    @available_conversion_tools ||= self.available_tools.scoped(:conditions  => {:category  => "conversion tool"}, :order  => "tools.select_menu_text" )
  end
  
  #Return the list of groups available to this user based on role.
  def available_groups(arg1 = :all, options = {})
    if self.has_role? :admin
      Group.find(arg1, options)
    elsif self.has_role? :site_manager
      site_groups = self.site.groups.find(arg1, options.clone) rescue []
      site_groups = [site_groups] unless site_groups.is_a?(Array) 
      self_groups = self.groups.find(arg1, options.clone) rescue []
      self_groups = [self_groups] unless self_groups.is_a?(Array)
            
      if site_groups.blank? and self_groups.blank?
        raise ActiveRecord::RecordNotFound, "Couldn't find Group with ID=#{arg1}"
      end
       
      all_groups = site_groups | self_groups
      all_groups = all_groups.first if all_groups.size == 1
      return all_groups
    else                  
      self.groups.find(arg1, options)
    end
  end
  
  def available_tasks
    @available_tasks ||= if self.has_role? :admin
                         CbrainTask.scoped({})
                       elsif self.has_role? :site_manager
                         CbrainTask.scoped(:conditions  => ["cbrain_tasks.user_id = ? OR cbrain_tasks.group_id IN (?) OR cbrain_tasks.user_id IN (?)", self.id, self.group_ids, self.site.user_ids])
                       else
                         CbrainTask.scoped(:conditions  => ["cbrain_tasks.user_id = ? OR cbrain_tasks.group_id IN (?)", self.id, self.group_ids])
                       end
  end
  
  #Return the list of users under this user's control based on role.
  def available_users
    return @available_users if @available_users
    
    if self.has_role? :admin
      @available_users = User.all
    elsif self.has_role? :site_manager
      @available_users = self.site.users.all
    else
      @available_users = [self]
    end
  end
  
  # Returns the SystemGroup associated with the user; this is a
  # group with the same name as the user.
  def system_group
    SystemGroup.find(:first, :conditions => { :name => self.login } )
  end

  # An alias for system_group()
  alias own_group system_group

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
    length = rand(5) + 6
    s = ""
    length.times do
      c = rand(75) + 48
      c += 1 if c == 96
      s << c
    end
    s
  end
   
  def prevent_group_collision #:nodoc:
    if self.login && (WorkGroup.find_by_name(self.login) || self.login == 'everyone') 
      errors.add(:login, "already in use by a group.")
    end
  end
  
  def create_user_preference #:nodoc:
    self.build_user_preference
  end
  
  def immutable_login #:nodoc:
    if self.changed.include? "login"
      errors.add(:login, "is immutable.")
    end
  end
  
  #Ensure that the system will be in a valid state if this user is destroyed.
  def validate_destroy
    if self.login == 'admin'
      cb_error "Default admin user cannot be destroyed.", :action  => :index
    end
    unless self.userfiles.empty?
      cb_error "User #{self.login} cannot be destroyed while there are still files on the account.", :action  => :index
    end
    unless self.data_providers.empty?
      cb_error "User #{self.login} cannot be destroyed while there are still data providers on the account.", :action  => :index
    end
    unless self.remote_resources.empty?
      cb_error "User #{self.login} cannot be destroyed while there are still remote resources on the account.", :action  => :index
    end
    destroy_system_group
  end
  
  def system_group_site_update  #:nodoc:
    SystemGroup.find_by_name(self.login).update_attributes(:site_id => self.site_id)
    
    if self.changed.include?("site_id")
      unless self.changes["site_id"].first.blank?
        old_site = Site.find(self.changes["site_id"].first)
        old_site_group = SystemGroup.find_by_name(old_site.name)
        old_site_group.users.delete(self)
      end
      new_site = Site.find(self.changes["site_id"].last)
      new_site_group = SystemGroup.find_by_name(new_site.name)
      new_site_group.users << self
    end
  end
  
  def site_manager_check  #:nodoc:
    if self.role == "site_manager" && self.site_id.blank?
      errors.add(:site_id, "manager role must be associated with a site.")
    end
  end
  
  def destroy_system_group #:nodoc:
    system_group = SystemGroup.find(:first, :conditions => {:name => self.login})
    system_group.destroy if system_group
  end
  
  def add_system_groups #:nodoc:
    newGroup = UserGroup.new(:name => self.login, :site  => self.site)
    newGroup.save!
    
    everyoneGroup = SystemGroup.find_by_name("everyone")
    group_ids = self.group_ids
    group_ids << newGroup.id
    group_ids << everyoneGroup.id
    if self.site
      site_group = SystemGroup.find_by_name(self.site.name)
      group_ids << site_group.id
    end
    self.group_ids = group_ids
  end

end
