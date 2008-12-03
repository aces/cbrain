
#
# CBRAIN Project
#
# Userfile model
#
# Original author: Tarek Sherif
#
# $Id$
#

class Userfile < ActiveRecord::Base

  Revision_info="$Id$"

  acts_as_nested_set :dependent => :destroy, :before_destroy => :move_children_to_root
  belongs_to              :user
  has_and_belongs_to_many :tags
  
  def self.search(type, term = nil)
    if type
      case type.to_sym
      when :tag_search
        files = find(:all, :include => :tags).select{|f| f.tags.find_by_name(term)} rescue find(:all, :include => :tags)
      when :name_search
        find(:all, :include => :tags, :conditions => ["name LIKE ?", "%#{term}%"])
      when :minc
        find(:all, :include => :tags, :conditions => ["name LIKE ?", "%.mnc"])
      when :jiv
        find(:all, :include => :tags, :conditions => ["name LIKE ? OR name LIKE ?", "%.raw_byte%", "%.header"])
      end
    else
      find(:all, :include =>:tags)
    end
  end
  
  def content
    @content ||= self.read_content
    @content
  end

  def content=(newcontent)
    @content = newcontent
    self.size = @content.size
    @content
  end
  
  def vaultname
    directory = Pathname.new(CBRAIN::Filevault_dir) + self.user.login
    (directory + self.name).to_s
  end
  
  def save_content
    out = File.open(self.vaultname, "w") { |io| io.write(@content) }
  end

  def delete_content
    vaultname = self.vaultname
    File.unlink(vaultname) if File.exists?(vaultname)
  end
  
  
  def after_save
    self.save_content
  end
  def after_update
    self.save_content
  end
  def after_create
    self.save_content
  end
  def after_destroy
    self.delete_content
  end
end
