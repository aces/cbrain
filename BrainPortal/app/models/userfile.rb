
#
# CBRAIN Project
#
# Userfile model
#
# Original author: Pierre Rioux
#
# $Id$
#

require "pathname"
require "base64"

class Userfile < ActiveRecord::Base

    validates_presence_of     :base_name, :owner_id
    validates_uniqueness_of   :base_name, :scope => [ :owner_id ]
    validates_numericality_of :owner_id

    Revision_info="$Id$"

    public

    # The "content" attribute is fetched/stored to a file, on demand;
    # it is not saved in the database like other ActiveRecord attributes

    def content
      @content ||= self.read_content
      @content
    end

    def content=(newcontent)
      @content = newcontent
      self.file_size = @content.size
      @content
    end

    # These two methods return/sets the content based on base64 encoding
    def content_base64
      @content ||= self.read_content
      Base64.encode64(@content)
    end

    def content_base64=(encoded)
      self.content=(Base64.decode64(encoded))
    end

    # This xml converter serializes all the normal fields
    # plus it adds a synthetic field 'content_base64' that
    # encodes the "content" pseudo-attribute in a XML-friendly way
    #def to_xml   # this one adds a <content> tag
    #  super :methods => [ :content_base64 ], :dasherize => false, :skip_types => true
    #end

    # This method forces read from the external file
    def read_content
      @content = File.read(self.vaultname)
      @content
    end

    def save_content
      out = File.open(self.vaultname, "w") { |io| io.write(@content) }
    end

    def delete_content
      vaultname = self.vaultname
      File.unlink(vaultname) if File.exists?(vaultname)
    end

    # Names of files in the vault are "{CBRAIN_VAULT}/user_name/basename"
    def vaultname
      user_id   = self.owner_id
      user_name = User.id2name(user_id)
      basename  = self.base_name
      userdir   = Pathname.new(CBRAIN::Filevault_dir) + user_name
      Dir.mkdir(userdir.to_s) unless File.directory?(userdir.to_s) # TODO : create only when creating user?
      (userdir + basename).to_s
    end

    def ownername
      user_id  = self.owner_id
      User.id2name(user_id) || "???"  # this class method caches its result
    end


    # These are ActiveRecords callbacks, invoked automatically
    # at different stages of the object's lifecycle

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
