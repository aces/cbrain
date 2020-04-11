
#
# CBRAIN Project
#
# Copyright (C) 2008-2020
# The Royal Institution for the Advancement of Learning
# McGill University
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# A class to represent a file accessible through SFTP or available locally.
# Most of the attributes here are compatible with
#   Net::SFTP::Protocol::V01::Attributes
class FileInfo

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  AttrList = [
                # Standard attributes from SFTP protocol
                :name, :symbolic_type, :size, :permissions,
                :uid, :gid, :owner, :group,
                :atime, :mtime, :ctime,

                # Used by CBRAIN to link remote files to registered files
                :userfile, :userfile_id, :state_ok, :message,
             ]

  attr_accessor(*AttrList)

  def initialize(attributes = {}) #:nodoc:
     (attributes.keys.collect(&:to_sym) & AttrList).each { |name| self.send("#{name}=",attributes[name]) }
  end

  # Return the depth of the file,
  # For example for file located at the following place:
  #   /first_dir/second_dir/file
  # it will return 3
  def depth #:nodoc:
    return @depth if @depth
    cb_error "File doesn't have a name." if self.name.blank?
    count = -1
    Pathname.new(self.name).cleanpath.descend{ count += 1}
    @depth = count
    @depth
  end

  def to_xml(options = {}) #:nodoc:
    require 'builder' unless defined?(Builder)

    options = options.dup
    options[:indent] ||= 2
    options.reverse_merge!({ :builder => Builder::XmlMarkup.new(:indent => options[:indent]),
                             :root => self.class.name.underscore.dasherize.tr('/', '-') })
    options[:builder].instruct! unless options.delete(:skip_instruct)
    root = options[:root].to_s

    options[:builder].__send__(:method_missing, root) do
      self.instance_variables.each do |key_sym|
        key = key_sym.to_s.sub "@", ""   # changes '@name' or :@name to 'name'
        value = self.__send__(key)
        options[:builder].tag!(key, value)
      end

      yield options[:builder] if block_given?
    end
  end

  def to_json #:nodoc:
    self.instance_variables.each do |key_sym|
        key = key_sym.to_s.sub "@", ""   # changes '@name' or :@name to 'name'
        value = self.__send__(key)
        options[:builder].tag!(key, value)
      end
    my_hash.to_json
  end

end

