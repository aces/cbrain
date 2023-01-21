
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

# This class provides the functionality necessary to create,
# destroy and manage persistent SSH keys.
#
# A key is a simple Ruby object, SshKey, that has only
# a single attribute, its +name+ .
#
# On the filesystem side, associated with the name are
# two files "id_#{name}" and "id_#{name}.pub" which
# are created by the external utility 'ssh-keygen'.
#
# Original author: Pierre Rioux
class SshKey

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Class configuration.
  CONFIG = { #:nodoc:
    :ssh_keys_dir     => (Rails.root rescue nil) ? "#{Rails.root.to_s}/user_keys" : "/not/yet/configured",
    :exec_ssh_keygen  => `bash -c "type -p ssh-keygen"`.strip,
    :ssh_keygen_type  => "rsa",
    :debug            => false,
  }

  # A name for the key; the two associated files
  # names will be "id_#{name}" and "id_#{name}.pub"
  attr_reader :name

  def initialize(name) #:nodoc:
    @name = name
    validate_name!
  end

  #----------------------------
  # Finder methods, class level
  #----------------------------

  # Find and return a key by name. Checks on the filesystem
  # that the two associated SSH key files exist.
  def self.find(name)
    key = self.new(name)
    key.validate!
    key
  end

  # Find a key, or create it as necessary. See
  # also the class method +create+.
  def self.find_or_create(name)
    key = self.find(name) rescue nil
    return key if key
    key = self.create(name)
    key
  end

  # Create and return a key. The SSH key files must not
  # already exist. These files will be created as a side effect.
  def self.create(name)
    key = self.new(name)
    key.create_key_files
    key
  end

  #----------------------------
  # Instance methods
  #----------------------------

  # Checks that the name of the key is
  # a proper alphanumeric identifier and
  # that the SSH key files exist.
  # Raise an exception if anything is wrong.
  def validate!
    validate_name!
    validate_files!
    true
  end

  # Like validate!, but returns true or false
  def valid?
    validate!
    true
  rescue
    false
  end

  # Checks that the name of the key is
  # a proper alphanumeric identifier.
  # Raise an exception if anything is wrong.
  def validate_name!
    raise RuntimeError.new("No valid name given for SSH key.") unless
      @name.present? &&
      @name =~ /\A[a-z]\w*\z/i # quite strict
    true
  end

  # Checks that the two SSH key files exist.
  # Raise an exception if anything is wrong.
  def validate_files!
    # Two files associated with each name
    pub_path  = public_key_path
    priv_path = private_key_path

    # Check that they seem valid
    raise RuntimeError.new("Public file for SSH Key '#{@name}' does not exist.")  unless
      File.exists?(pub_path)  && File.size(pub_path)  > 50
    raise RuntimeError.new("Private file for SSH Key '#{@name}' does not exist.") unless
      File.exists?(priv_path) && File.size(priv_path) > 1000
    true
  end

  # Create the two key files for the key.
  def create_key_files
    # Valid stuff
    validate_name!
    files_exist = validate_files! rescue nil
    raise RuntimeError.new("Key files for SSH key '#{@name}' already exist.") if files_exist
    # Build both keyfiles
    path_prefix = private_key_path
    ssh_keygen  = CONFIG[:exec_ssh_keygen].presence
    keygen_type = CONFIG[:ssh_keygen_type].presence || "rsa"
    comment     = self.comment
    redir       = CONFIG[:debug] ? "" : ">/dev/null 2>/dev/null"
    ret         = system "#{ssh_keygen} "                        +
                           "-N '' "                              +
                           "-t #{keygen_type} "                  +
                           "-C #{comment.bash_escape} "          +
                           "-f #{path_prefix.to_s.bash_escape} " +
                           redir
    raise RuntimeError.new("Could not create key files for SSH key '#{@name}'.") unless ret
    true
  end

  # Returns the path to the public key file.
  def public_key_path
    keys_dir + "id_#{@name}.pub"
  end

  # Returns the public key (in SSH format)
  def public_key
    @_pub_key_ ||= File.read(public_key_path)
  end

  # Removes the two SSH key files
  def destroy
    File.unlink private_key_path rescue true
    File.unlink public_key_path  rescue true
    true
  end

  # Returns the date that the SSH key files were created.
  def created_at
    validate!
    File.stat(public_key_path.to_s).mtime
  end

  # Installs (or crushes) the key files
  def install_key_files(pub_key, priv_key)
    validate_name!
    File.open(public_key_path.to_s,  "w") { |fh| fh.write(pub_key)  }
    File.open(private_key_path.to_s, "w") { |fh| fh.write(priv_key) }
    File.chmod(0700, public_key_path.to_s)
    File.chmod(0700, private_key_path.to_s)
    true
  end

  protected

  def comment #:nodoc:
    rev     = self.revision_info
    "#{@name}@#{rev.basename}/#{rev.short_commit}"
  end

  def keys_dir #:nodoc:
    self.class.keys_dir
  end

  def self.keys_dir #:nodoc:
    return @_dir_ if @_dir_
    @_dir_ = Pathname.new(CONFIG[:ssh_keys_dir])
    File.chmod(0700, @_dir_.to_s) # security check
    @_dir_
  end

  private

  # Returns the path to the private key file.
  # Do not open the content of this file, ever!
  def private_key_path
    keys_dir + "id_#{@name}"
  end

  # Returns the private key (in SSH format)
  def private_key(i_know_what_i_am_doing = false)
    raise RuntimeError.new("Private key access denied") unless i_know_what_i_am_doing == 'I Know What I Am Doing'
    File.read(private_key_path)
  end

end
