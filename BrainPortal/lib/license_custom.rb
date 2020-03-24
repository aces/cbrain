
#
# CBRAIN Project
#
# Copyright (C) 2008-2012
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
#license_for_groups.rb



# Module containing common methods for set and access the user create, custom user-agreements
# license agreements. Differently from the original, user can create his own licences
module LicenseCustom

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  require 'securerandom'

  # Check that the the class this module is being included into is a valid one.
  def self.included(includer) #:nodoc:
    unless includer <= ApplicationRecord
      raise "#{includer} is not an ActiveRecord model. The LicenseCustom module cannot be used with it."
    end

    includer.class_eval do
      # License agreement is a pseudo attributes and cannot be accessed if the object is not saved.
      validate   :valid_license_agreements?
      after_save :register_license_agreements
    end
  end

  # Returns the list of license agreements that exists for this object.
  def license_agreements
    @license_agreements ||= load_license_agreements
  end

  # Sets the list of license agreements that exists for this object.
  # Can be provided with an array of license names, or a single string with
  # a space-or-comma-separated list of license names.
  def license_agreements=(agreements)
    license_agreements # loads them if not already loaded
    agrs = agreements
    unless agrs.is_a? Array
      agrs = agrs.to_s.split(/[,\s]+/)
    end
    agrs = agrs.map { |a| a.sub(/\.html\z/, "").gsub(/[^\w-]+/, "") }.uniq.sort
    @license_agreements = agrs
  end

  # create a license file
  def create_license_file(content, user, basename=nil)
    basename ||= "license_#{SecureRandom.uuid().to_s}.txt"
    userfile = create_file(content, user, basename)
    license_agreements << userfile.id.to_s
    register_license_agreements
    # post save trigger
  end

  protected

  # Loads the licenses from the meta data store.
  def load_license_agreements
    @license_agreements           = self.new_record? ? [] : self.meta[:license_agreements].presence || []
    @_license_agreements_original = @license_agreements.dup # to determine if anything changed when saving
    @license_agreements
  end

  # Returns true if the set of licenses are identifiers that
  # properly match files on the filesystem, in public/licenses/{name}.html
  def valid_license_agreements?
    invalid_licenses = license_agreements.select do |license|
      Userfile.find(license) 
    end

    if invalid_licenses.presence
      invalid_licenses_list = invalid_licenses.join(", ")
      self.errors.add(:base, "Some licence agreement files do not exist: #{invalid_licenses_list}\nPlease inform the maintainers or admins to fix issues with files.\n")
      return false
    end
    return true
  end

  def create_file(content, user, basename) #:nodoc:
    
    file_type = TextFile
    
    # Temp file where the data is saved 
    tmpcontentfile     = "/tmp/#{Process.pid}-#{rand(10000).to_s}-#{basename}" # basename's extension is used later on

    File.open(tmpcontentfile, "w+") do |f|
      f.write(content)
    end

    dest_dp_id   = DataProvider.find_by_id(user.meta["pref_data_provider_id"]).try(:id)
    dest_dp_id ||= DataProvider.find_all_accessible_by_user(user).where(:online => true).first.try(:id)

    # set to official DataProvider for Neurohub once it is ready?

    userfile  = file_type.new(
        {
            :name             => basename,
            :user_id          => user.id,
            :data_provider_id => dest_dp_id,
            :group_id => user.own_group.id
            
        }
    )

    userfile.group_id = user.own_group.id

    userfile.save

    if !userfile.save
      return nil
    end

    userfile.cache_copy_from_local_file(tmpcontentfile)
    userfile.size = content.length
    userfile.immutable = true
    userfile.save
    userfile.addlog_context(self, "License, created by #{user.login}")
    Message.send_message(user,
                             :message_type   => 'notice',
                             :header         => "License File added",
                             :variable_text  => "#{userfile.pretty_type} [[#{userfile.name}][/userfiles/#{userfile.id}]]"
        )
    File.delete(tmpcontentfile) rescue true
    userfile
  end

  # writes back the license agreements array
  # to the meta data store
  def register_license_agreements
    return true if @license_agreements.nil? # nothing to do if they were never loaded or updated
    # To keep pre_register licenses agreement, useful when the console is used to save the object
    new_agreements  = (license_agreements || []).sort
    orig_agreements = (@_license_agreements_original || []).sort
    return true if new_agreements == orig_agreements
    self.meta[:license_agreements] = license_agreements
    true
  end

end
