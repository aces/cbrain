require "pathname"

class Userfile < ActiveRecord::Base

    validates_presence_of     :base_name, :owner_id
    validates_uniqueness_of   :base_name, :scope => [ :owner_id ]
    validates_numericality_of :owner_id

    public

    # These are temp storage variables used when uploading a new file
    attr_accessor :tmp_basename, :tmp_type, :content

    def upload_file(upload_field)
      self.tmp_basename = Userfile.base_part_of(upload_field.original_filename)
      self.tmp_type     = upload_field.content_type.chomp
      self.content      = upload_field.read
    end

    # Names of files in the vault are "{CBRAIN_VAULT}/nnn/basename" where nnn is user_id
    def vaultname
      user_id   = self.owner_id
      user_name = User.id2name(user_id)
      basename  = self.base_name
      vaultdir  = CBRAIN.filevault_dir
      userdir   = Pathname.new(vaultdir) + user_name
      Dir.mkdir(userdir.to_s) unless File.directory?(userdir.to_s) # TODO : create only when creating user?
      (userdir + basename).to_s
    end

    def ownername
      user_id  = self.owner_id
      User.id2name(user_id) || "???"  # this class method caches its result
    end
   

    private

    def self.base_part_of(file_name)
        name = File.basename(file_name)
        name.gsub(/[^\w._-]/, '')
        name
    end 
    
    def self.directory(file_name)
      base = self.base_part_of(file_name)
      file_name.sub(/#{base}$/, '')
    end

end
