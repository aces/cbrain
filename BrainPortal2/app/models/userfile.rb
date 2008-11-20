class Userfile < ActiveRecord::Base
  acts_as_nested_set :dependent => :destroy, :before_destroy => :move_children_to_root
  belongs_to :user
  
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
