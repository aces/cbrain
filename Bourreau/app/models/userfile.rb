
#
# CBRAIN Project
#
# Userfile model as an ActiveResource
#
# Original author: Pierre Rioux
#
# $Id$
#

require "pathname"

class Userfile < ActiveResource::Base

    Revision_info="$Id$"

    self.site = CBRAIN.filemanager_resource_url

    def mktemp
        tmpfilename = Pathname.new(Dir.tmpdir) + ("userfile." + Process.pid.to_s)
        io = File.new(tmpfilename.to_s,"w")
        io.write(self.content)
        io.close
        tmpfilename
    end

    attr_accessor :content

    # These two methods return/sets the content based on base64 encoding
    def content_base64
      Base64.encode64(@content)
    end

    def content_base64=(encoded)
      self.content=(Base64.decode64(encoded))
    end

    # This xml converter serializes all the normal fields
    # plus it adds a synthetic field 'content_base64' that
    # encodes the "content" pseudo-attribute in a XML-friendly way
    def to_xml   # this one adds a <content> tag
      super :methods => [ :content_base64 ], :dasherize => false, :skip_types => true
    end
           
end
