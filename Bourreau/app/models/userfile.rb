
#
#= CBRAIN Project
#
#== Userfile model as an ActiveResource
#
#== Original author: Pierre Rioux
#
#== $Id$
#

require "pathname"

class Userfile < ActiveResource::Base

    Revision_info="$Id$"

    self.site = CBRAIN::Userfiles_resource_URL

    # Creates a temporary copy of the content of the file
    # in a temporary directory; options are
    #     :basename => "myname" # provide the temp file's basename.
    #     :ext => ".abc"        # will give the extension ".abc" to the temp file
    # Returns the full pathname to the temp file, usually like "/tmp/x-1234567"
    def mktemp(options = {})
        extension = options[:ext] || ""
        basename  = options[:basename] || ("x" + self.object_id.to_s)
        tmpfilename = Pathname.new(Dir.tmpdir) + (basename + extension)
        File.open(tmpfilename.to_s,"w") { |io| io.write(self.content) }
        tmpfilename
    end

    # This methods MUST be manually called afetr a find(), to convert
    # back the base64 encoded content into the original content.
    # At least until ActiveResource implements callbacks like ActiveRecord.
    # Note that this method modifies the underlying "attributes" hash
    # of the ActiveResource object; until a better mechanism is found/created
    # this is not garanteed to work in the future.
    def after_find
        return nil unless self.attributes.has_key?("content_base64") # if callbacks ever become implemented, will prevent trying to run this methods twice in a row
        self.attributes["content"] = Base64.decode64(self.attributes["content_base64"])
        self.attributes.delete("content_base64")
        true
    end

    # Sets the content of the file; doing this also sets
    # the "file_size" attribute automatically
    def content=(newcontent)
      self.file_size=newcontent.size
      super(newcontent)
    end

    # This method returns the content based on base64 encoding
    # It's not meant to be used by an application, but rather
    # is used internally by to_xml to add a pseudo field named
    # <content_base64> to the XML record encoding the object
    def content_base64
      Base64.encode64(self.content)
    end

    # This method sets the content of the object from a base64
    # encoded string. It's not meant to be used by an application,
    # but rather is used internally when reconstructing an object
    # obtained from the remote ActiveResource XML, which contains
    # a pseudo field <content_base64>
    def content_base64=(encoded)
      self.content=(Base64.decode64(encoded))
    end

#    # This xml converter serializes all the normal fields
#    # plus it adds a synthetic field 'content_base64' that
#    # encodes the "content" pseudo-attribute in a XML-friendly way
#    def to_xml
#
#      # Do some temporary damage for recoding
#      content = self.attributes.delete("content")
#      self.attributes["content_base64"] = Base64.encode64(content)
#
#      super :methods => [ :content_base64 ], :dasherize => false, :skip_types => true, :except => [ :content ]
#
#      # Undo damage
#      self.attributes.delete("content_base64")
#      self.attributes["content"] = content
#
#    end

    # TODO support create too?
    def save

puts "===USERFILE ACTIVERESOURCE MODEL: SAVING\n"

      # Do some temporary damage for recoding
      content = self.attributes.delete("content")
      self.attributes["content_base64"] = Base64.encode64(content)

      ret = super

      # Undo damage
      self.attributes.delete("content_base64")
      self.attributes["content"] = content

      ret
    end

end
