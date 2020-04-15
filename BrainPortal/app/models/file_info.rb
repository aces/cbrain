
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

  # Verify that the information we have about this file
  # seems to make it acceptable for registration. Sets
  # the state_ok to true or false depending on result.
  # Also sets an error message in the +message+ attribute
  # if the result is false. This method will also compare
  # the information in the FileInfo with the information
  # in the userfile attribute, if any, and highlight
  # any type inconsistency.
  def validate_for_registration

    self.message     = ""
    self.state_ok    = true

    fi_type    = self.symbolic_type
    registered = self.userfile # if already registered
    if registered
      unless ((fi_type == :symlink)                                    ||
              (fi_type == :regular    && registered.is_a?(SingleFile)) ||
              (fi_type == :directory  && registered.is_a?(FileCollection)))
        self.message  = "Conflicting types!"
        self.state_ok = false
      end
    end

    # Check filename's validity
    if ! Userfile.is_legal_filename?(self.name)
      self.message  += ", " if self.message.present?
      self.message  += "Illegal characters in filename."
      self.state_ok  = false
    end

    self.state_ok
  end

  # Given a +userfile+, this will fill the
  # two FileInfo attribute +userfile+ and +userfile_id+
  # with that userfile. A check is made to make sure
  # that the name in the FileInfo matches exactly
  # the name in the userfile.
  def match_info_from_userfile(userfile)
    cb_error "Mismatch in names: FileInfo: '#{self.name}' vs Userfile: '#{userfile.name}'" unless
      self.name == userfile.name
    self.userfile    = userfile
    self.userfile_id = userfile.id
    self
  end

  # Utility method. Given a set of +file_infos+ and a set of
  # +userfiles+, this will set the two attributes +userfile+
  # and +userfile_id+ in each file_info to associate it
  # to a specific userfile. The match is made only when
  # there is an exact same name on each side.
  #
  # This method is usually invoked when building a set
  # of FileInfo objects describing basenames on a remote
  # DataProvider, and we want to know which ones are registered
  # already in the DB or not. So the set of +userfiles+ passed
  # in argument should be carefully considered before making
  # the match, to represent only files that are know to have
  # been on the remote side previously.
  def self.array_match_all_userfiles(file_infos, userfiles)
    userfiles_by_names = userfiles.to_a.index_by(&:name)
    file_infos.each do |fi|
      next if fi.userfile_id # already done? skip it
      userfile = userfiles_by_names[fi.name]
      next unless userfile
      fi.match_info_from_userfile(userfile)
    end
    file_infos
  end

  # Utility method; runs validate_for_registration on all
  # FileInfos.
  def self.array_validate_for_registration(file_infos)
    file_infos.each(&:validate_for_registration)
  end

  ########################################
  # Serializers
  ########################################

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

  # This serializer only seems to work when invoked
  # from Rails's controllers when in "render :json"...
  def to_json #:nodoc:
    self.instance_variables.each do |key_sym|
        key = key_sym.to_s.sub "@", ""   # changes '@name' or :@name to 'name'
        value = self.__send__(key)
        options[:builder].tag!(key, value)
      end
    my_hash.to_json
  end

end

