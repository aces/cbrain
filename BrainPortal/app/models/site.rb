class Site < ActiveRecord::Base                                                             
  validates_presence_of   :name
  validates_uniqueness_of :name
  
  before_save            :save_old_manager_ids,
                         :save_old_user_ids
  after_save             :set_managers,
                         :set_system_groups
  before_destroy         :unset_managers
  
  has_many        :users,  :dependent => :nullify, :after_remove  => :user_system_group_remove
  has_many        :groups, :dependent => :nullify
  
  attr_accessor           :manager_ids
  
  def managers
    @managers ||= self.users.find(:all, :conditions  =>  ["(users.role IN (?))", ["admin", "site_manager"]]) || []
  end
  
  def userfiles_find_all(options = {})
    raise "Options :joins and :conditions cannont be used with this method. They are set internally." if options[:joins] || options[:conditions]
    options.merge!( :joins => :user, :conditions => ["users.site_id = ?", self.id])
    @userfiles ||= Userfile.find(:all, options)
  end
  
  def remote_resources_find_all(options = {})
    raise "Options :joins and :conditions cannont be used with this method. They are set internally." if options[:joins] || options[:conditions]
    options.merge!( :joins => :user, :conditions => ["users.site_id = ?", self.id])
    @remote_resources ||= RemoteResource.find(:all, options)
  end
  
  def data_providers_find_all(options = {})
    raise "Options :joins and :conditions cannont be used with this method. They are set internally." if options[:joins] || options[:conditions]
    options.merge!( :joins => :user, :conditions => ["users.site_id = ?", self.id])
    @data_provider ||= DataProvider.find(:all, options)
  end
  
  def userfiles_find_id(id, options = {})
    raise "Options :joins and :conditions cannont be used with this method. They are set internally." if options[:joins] || options[:conditions]
    options.merge!( :joins => :user, :conditions => ["users.site_id = ?", self.id])
    @userfiles ||= Userfile.find(id, options)
  end
  
  def remote_resources_find_id(id, options = {})
    raise "Options :joins and :conditions cannont be used with this method. They are set internally." if options[:joins] || options[:conditions]
    options.merge!( :joins => :user, :conditions => ["users.site_id = ?", self.id])
    @remote_resources ||= RemoteResource.find(id, options)
  end
  
  def data_providers_find_id(id, options = {})
    raise "Options :joins and :conditions cannont be used with this method. They are set internally." if options[:joins] || options[:conditions]
    options.merge!( :joins => :user, :conditions => ["users.site_id = ?", self.id])
    @data_provider ||= DataProvider.find(id, options)
  end
  
  private
  
  def user_system_group_remove(user)
    if user.has_role? :site_manager
      user.update_attributes!(:role  => "user")
    end
    SystemGroup.find_by_name(user.login).update_attributes!(:site => nil)
  end
  
  def save_old_manager_ids
    @old_manager_ids = self.managers.collect{ |m| m.id.to_s }
  end
  
  def save_old_user_ids
    @old_user_ids = self.users.collect{ |m| m.id.to_s }
  end
  
  def set_managers
    current_manager_ids = self.manager_ids || []
    @new_manager_ids   = current_manager_ids - @old_manager_ids
    
    User.find(@new_manager_ids).each do |user|
      if user.has_role? :user
        user.update_attributes(:site_id  => self.id, :role  => "site_manager")
      else
        user.update_attributes(:site_id  => self.id)
      end
    end
  end
  
  def set_system_groups
    current_user_ids = self.user_ids || []
    @new_user_ids   = current_user_ids - @old_user_ids
    @unset_user_ids = @old_user_ids - current_user_ids    
    
    User.find(@new_user_ids).each do |user|
      SystemGroup.find_by_name(user.login).update_attributes!(:site  => self)
    end
  end
  
  def unset_managers
    self.managers.each do |user|
      if user.has_role? :site_manager
        user.update_attributes!(:role  => "user")
      end
    end
  end
end
